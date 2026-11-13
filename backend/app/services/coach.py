"""AI Coach: trò chuyện về số liệu sức khỏe bằng Claude, có tool use và nhận xét tuần.

Mô hình chat mặc định là Haiku 5.5 (nhanh, rẻ), báo cáo tuần dùng Sonnet 5.5. Không đặt
``temperature`` (Sonnet 5.5 từ chối giá trị khác mặc định) và không ép ``tool_choice``.
"""

import json
from collections.abc import AsyncIterator
from datetime import timedelta
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.coach_insight import CoachInsight
from app.models.user import User
from app.schemas.coach import CoachMessage, WeeklyInsight
from app.services import coach_tools
from app.services.stats import local_today

MAX_TOOL_ROUNDS = 5
REFUSAL_TEXT = (
    "Mình không thể giúp với yêu cầu này. Bạn thử hỏi về thói quen sức khỏe của mình nhé."
)

SYSTEM_PROMPT = """Bạn là HealthTrack Coach, trợ lý theo dõi sức khỏe trong ứng dụng HealthTrack.

Cách làm việc:
- Trả lời bằng tiếng Việt, ngắn gọn, thân thiện, dùng câu thường, không dùng định dạng nặng.
- Chưa có số liệu thì gọi get_stats hoặc get_goals trước, không đoán số.
- Chỉ gọi log_entry khi người dùng nói rõ họ đã làm điều đó (uống nước, ngủ, ăn, cân, đi bộ). \
Sau khi ghi, nói lại bạn đã ghi gì. Hỏi lại nếu thiếu thông tin cần thiết \
(ví dụ chưa biết bao nhiêu ml).
- Không chẩn đoán bệnh, không kê thuốc hay liều dùng. Với triệu chứng đáng lo hoặc câu hỏi y tế, \
khuyên gặp bác sĩ. Bạn chỉ là công cụ hỗ trợ thói quen, không thay thế tư vấn y tế.
- Nhận xét dựa trên dữ liệu thật, nêu một việc nhỏ cụ thể nên làm tiếp, đừng dạy đời."""

WEEKLY_PROMPT = """Viết nhận xét tuần cho người dùng HealthTrack từ số liệu 7 ngày dưới đây.
Yêu cầu: tiếng Việt, tối đa 120 từ, gồm một điểm tích cực, một điểm cần cải thiện và một việc \
cụ thể nên làm tuần tới. Không chẩn đoán y tế. Không lặp lại bảng số liệu."""


class CoachUnavailableError(Exception):
    """Chưa cấu hình ANTHROPIC_API_KEY."""


def make_client() -> Any:
    """Tạo client Claude; ném CoachUnavailableError nếu chưa có khóa."""
    if not settings.ANTHROPIC_API_KEY:
        raise CoachUnavailableError
    import anthropic

    return anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)


def _system(tz_offset: int) -> str:
    today = local_today(tz_offset)
    return f"{SYSTEM_PROMPT}\n\nHôm nay là {today.isoformat()} (múi giờ UTC{tz_offset / 60:+g})."


async def stream_chat(
    db: AsyncSession,
    user: User,
    client: Any,
    messages: list[CoachMessage],
    tz_offset: int,
) -> AsyncIterator[dict[str, Any]]:
    """Chạy vòng lặp tool use, phát từng sự kiện: text, tool, done hoặc error."""
    history: list[dict[str, Any]] = [{"role": m.role, "content": m.content} for m in messages]
    system = _system(tz_offset)
    for _ in range(MAX_TOOL_ROUNDS):
        async with client.messages.stream(
            model=settings.COACH_CHAT_MODEL,
            max_tokens=2000,
            system=system,
            tools=coach_tools.TOOLS,
            messages=history,
        ) as stream:
            async for text in stream.text_stream:
                yield {"type": "text", "text": text}
            final = await stream.get_final_message()

        if final.stop_reason == "refusal":
            yield {"type": "text", "text": REFUSAL_TEXT}
            break
        if final.stop_reason != "tool_use":
            break

        history.append({"role": "assistant", "content": final.content})
        results = []
        for block in final.content:
            if block.type != "tool_use":
                continue
            yield {"type": "tool", "name": block.name}
            content, is_error = await coach_tools.run_tool(
                db, user, block.name, dict(block.input), tz_offset
            )
            if block.name == "log_entry" and not is_error:
                yield {"type": "logged", "metric": block.input.get("metric")}
            results.append(
                {
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": content,
                    "is_error": is_error,
                }
            )
        history.append({"role": "user", "content": results})
    else:
        yield {"type": "text", "text": "\n(Mình đã dùng hết số bước cho một câu trả lời.)"}
    yield {"type": "done"}


def week_start(tz_offset: int) -> Any:
    today = local_today(tz_offset)
    return today - timedelta(days=today.weekday())


async def weekly_insight(
    db: AsyncSession, user: User, client: Any, tz_offset: int
) -> WeeklyInsight:
    """Nhận xét của tuần hiện tại; sinh một lần rồi lưu lại."""
    start = week_start(tz_offset)
    row = (
        await db.execute(
            select(CoachInsight).where(
                CoachInsight.user_id == user.id, CoachInsight.week_start == start
            )
        )
    ).scalar_one_or_none()
    if row is None:
        stats = await coach_tools.get_stats(db, user, 7, tz_offset)
        goals = await coach_tools.get_goals(db, user)
        digest = json.dumps({"stats": stats, "goals": goals}, ensure_ascii=False)
        response = await client.messages.create(
            model=settings.COACH_WEEKLY_MODEL,
            max_tokens=1000,
            system=WEEKLY_PROMPT,
            messages=[{"role": "user", "content": digest}],
        )
        if response.stop_reason == "refusal":
            text = REFUSAL_TEXT
        else:
            text = "".join(b.text for b in response.content if b.type == "text").strip()
        row = CoachInsight(
            user_id=user.id, week_start=start, content=text, model=settings.COACH_WEEKLY_MODEL
        )
        db.add(row)
        await db.commit()
    return WeeklyInsight(week_start=row.week_start, content=row.content, model=row.model)
