import json
from collections.abc import AsyncIterator
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.config import settings
from app.core.db import get_db
from app.core.rate_limit import RateLimiter
from app.schemas.coach import CoachChatRequest, CoachProviders, WeeklyInsight
from app.services import coach as coach_service
from app.services import coach_local

router = APIRouter(prefix="/coach", tags=["coach"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
TzOffset = Annotated[int, Query(ge=-720, le=840)]

coach_limiter = RateLimiter(settings.COACH_RATE_LIMIT, settings.COACH_RATE_WINDOW_SECONDS)


def get_coach_client() -> Any:
    """Client Claude, hoặc None khi chưa cấu hình khóa API. Test thay bằng client giả."""
    try:
        return coach_service.make_client()
    except coach_service.CoachUnavailableError:
        return None


def _need_claude(client: Any) -> Any:
    if client is None:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, "AI Coach chưa được bật trên máy chủ"
        )
    return client


CoachClient = Annotated[Any, Depends(get_coach_client)]


def _limit(user_id: int) -> None:
    wait = coach_limiter.hit(str(user_id))
    if wait:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Bạn hỏi hơi nhanh, thử lại sau ít phút",
            headers={"Retry-After": str(wait)},
        )


@router.get("/providers", response_model=CoachProviders)
async def providers(user: CurrentUser, client: CoachClient) -> CoachProviders:
    """Nguồn trả lời nào đang dùng được; app dùng để hiện công tắc chế độ riêng tư."""
    local = await coach_local.is_available()
    has_claude = client is not None
    return CoachProviders(
        claude=has_claude,
        local=local,
        default="local" if local else ("claude" if has_claude else None),
    )


@router.post("/chat")
async def chat(
    body: CoachChatRequest, user: CurrentUser, db: DbSession, client: CoachClient
) -> StreamingResponse:
    """Trò chuyện với Coach, trả về luồng SSE: mỗi dòng `data:` là một JSON có `type`
    là `meta` (nguồn trả lời), `text`, `tool`, `logged`, `done` hoặc `error`."""
    if body.messages[-1].role != "user":
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Tin nhắn cuối phải của bạn")
    _limit(user.id)

    use_local = body.provider == "local" or (
        body.provider == "auto" and await coach_local.is_available()
    )
    if use_local and not await coach_local.is_available():
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, "Máy chủ AI local chưa chạy trên Mac của bạn"
        )
    if not use_local:
        _need_claude(client)

    async def events() -> AsyncIterator[str]:
        try:
            meta = {"type": "meta", "provider": "local" if use_local else "claude"}
            yield f"data: {json.dumps(meta)}\n\n"
            source = (
                coach_local.stream_chat(db, user, body.messages, body.tz_offset)
                if use_local
                else coach_service.stream_chat(db, user, client, body.messages, body.tz_offset)
            )
            async for event in source:
                yield f"data: {json.dumps(event, ensure_ascii=False)}\n\n"
        except Exception:  # lỗi từ model giữa chừng: báo cho app thay vì cắt ngang luồng
            err = {"type": "error", "message": "Coach đang bận, thử lại sau nhé"}
            yield f"data: {json.dumps(err, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        events(), media_type="text/event-stream", headers={"Cache-Control": "no-cache"}
    )


@router.get("/weekly", response_model=WeeklyInsight)
async def weekly(
    user: CurrentUser, db: DbSession, client: CoachClient, tz_offset: TzOffset = 0
) -> WeeklyInsight:
    """Nhận xét tuần này; lưu lại nên các lần gọi sau trong tuần không tốn thêm."""
    _need_claude(client)
    _limit(user.id)
    try:
        return await coach_service.weekly_insight(db, user, client, tz_offset)
    except Exception:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, "Không tạo được nhận xét lúc này"
        ) from None
