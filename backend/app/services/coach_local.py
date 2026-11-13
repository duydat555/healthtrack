"""AI local: gọi server MLX (API tương thích OpenAI) chạy trên Mac của người dùng.

Model local chỉ trả lời, không có công cụ: số liệu được tóm tắt sẵn từ CSDL rồi đưa vào lời nhắc,
nên dữ liệu không rời khỏi máy của người dùng. Việc ghi chỉ số bằng câu tự nhiên vẫn dùng Claude.
"""

import json
import re
from collections.abc import AsyncIterator
from typing import Any

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.user import User
from app.schemas.coach import CoachMessage
from app.services import coach_tools
from app.services.coach import SYSTEM_PROMPT, _system

LOCAL_NOTE = """
Bạn đang chạy ở chế độ riêng tư trên máy của người dùng và không có công cụ ghi dữ liệu. \
Nếu người dùng muốn ghi một chỉ số, hãy bảo họ dùng nút + trong ứng dụng hoặc tắt chế độ riêng tư. \
Dưới đây là số liệu của họ, đã có sẵn, hãy dùng khi trả lời."""

_THINK = re.compile(r"<think>.*?</think>", re.DOTALL)


def configured() -> bool:
    return bool(settings.LOCAL_LLM_URL)


def _headers() -> dict[str, str]:
    key = settings.LOCAL_LLM_API_KEY
    return {"Authorization": f"Bearer {key}"} if key else {}


async def is_available() -> bool:
    """Server local có đang trả lời không (kiểm tra nhanh, không ném lỗi)."""
    if not configured():
        return False
    try:
        async with httpx.AsyncClient(timeout=2.0) as http:
            res = await http.get(f"{settings.LOCAL_LLM_URL.rstrip('/')}/models", headers=_headers())
        return res.status_code == 200
    except httpx.HTTPError:
        return False


async def _lines(body: dict[str, Any]) -> AsyncIterator[str]:
    """Từng dòng SSE của server local."""
    timeout = httpx.Timeout(settings.LOCAL_LLM_TIMEOUT_SECONDS, connect=3.0)
    async with httpx.AsyncClient(timeout=timeout) as http:
        async with http.stream(
            "POST",
            f"{settings.LOCAL_LLM_URL.rstrip('/')}/chat/completions",
            json=body,
            headers=_headers(),
        ) as res:
            res.raise_for_status()
            async for line in res.aiter_lines():
                yield line


class _ThinkFilter:
    """Bỏ phần suy nghĩ `<think>...</think>` mà một số model local in ra, kể cả khi thẻ bị cắt
    giữa hai mẩu."""

    def __init__(self) -> None:
        self._buf = ""
        self._inside = False

    def feed(self, chunk: str) -> str:
        self._buf += chunk
        out = ""
        while True:
            if self._inside:
                end = self._buf.find("</think>")
                if end < 0:
                    self._buf = self._buf[-8:]  # giữ lại đuôi phòng thẻ đóng bị cắt đôi
                    return out
                self._buf = self._buf[end + len("</think>") :].lstrip("\n")
                self._inside = False
                continue
            start = self._buf.find("<think>")
            if start >= 0:
                out += self._buf[:start]
                self._buf = self._buf[start + len("<think>") :]
                self._inside = True
                continue
            # Chưa thấy thẻ mở: giữ lại phần đuôi có thể là đầu của "<think>"
            keep = max((n for n in range(1, 7) if "<think>".startswith(self._buf[-n:])), default=0)
            out += self._buf[: len(self._buf) - keep]
            self._buf = self._buf[len(self._buf) - keep :]
            return out

    def flush(self) -> str:
        rest = "" if self._inside else self._buf
        self._buf = ""
        return rest


async def complete(system: str, user_text: str) -> str:
    """Một lượt hỏi, gom lại thành một chuỗi (dùng cho nhận xét tuần)."""
    body = {
        "model": settings.LOCAL_LLM_MODEL,
        "stream": True,
        "max_tokens": 800,
        "chat_template_kwargs": {"enable_thinking": False},
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user_text},
        ],
    }
    think = _ThinkFilter()
    out = ""
    async for line in _lines(body):
        if not line.startswith("data:") or line.endswith("[DONE]"):
            continue
        choices = json.loads(line[5:]).get("choices") or [{}]
        if delta := (choices[0].get("delta") or {}).get("content"):
            out += think.feed(delta)
    return (out + think.flush()).strip()


async def stream_chat(
    db: AsyncSession, user: User, messages: list[CoachMessage], tz_offset: int
) -> AsyncIterator[dict[str, Any]]:
    stats = await coach_tools.get_stats(db, user, 7, tz_offset)
    goals = await coach_tools.get_goals(db, user)
    context = json.dumps({"stats": stats, "goals": goals}, ensure_ascii=False)
    system = f"{_system(tz_offset)}{LOCAL_NOTE}\n\n{context}"
    body = {
        "model": settings.LOCAL_LLM_MODEL,
        "stream": True,
        "max_tokens": 1200,
        "chat_template_kwargs": {"enable_thinking": False},
        "messages": [{"role": "system", "content": system}]
        + [{"role": m.role, "content": m.content} for m in messages],
    }
    think = _ThinkFilter()
    async for line in _lines(body):
        if not line.startswith("data:") or line.endswith("[DONE]"):
            continue
        choices = json.loads(line[5:]).get("choices") or [{}]
        delta = (choices[0].get("delta") or {}).get("content")
        if delta and (text := think.feed(delta)):
            yield {"type": "text", "text": text}
    if tail := think.flush():
        yield {"type": "text", "text": tail}
    yield {"type": "done"}


__all__ = ["SYSTEM_PROMPT", "complete", "configured", "is_available", "stream_chat"]
