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
from app.schemas.coach import CoachChatRequest, WeeklyInsight
from app.services import coach as coach_service

router = APIRouter(prefix="/coach", tags=["coach"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
TzOffset = Annotated[int, Query(ge=-720, le=840)]

coach_limiter = RateLimiter(settings.COACH_RATE_LIMIT, settings.COACH_RATE_WINDOW_SECONDS)


def get_coach_client() -> Any:
    """Dependency để test thay bằng client giả; 503 khi chưa cấu hình khóa API."""
    try:
        return coach_service.make_client()
    except coach_service.CoachUnavailableError:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, "AI Coach chưa được bật trên máy chủ"
        ) from None


CoachClient = Annotated[Any, Depends(get_coach_client)]


def _limit(user_id: int) -> None:
    wait = coach_limiter.hit(str(user_id))
    if wait:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Bạn hỏi hơi nhanh, thử lại sau ít phút",
            headers={"Retry-After": str(wait)},
        )


@router.post("/chat")
async def chat(
    body: CoachChatRequest, user: CurrentUser, db: DbSession, client: CoachClient
) -> StreamingResponse:
    """Trò chuyện với Coach, trả về luồng SSE: mỗi dòng `data:` là một JSON có `type`
    là `text`, `tool`, `logged`, `done` hoặc `error`."""
    if body.messages[-1].role != "user":
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Tin nhắn cuối phải của bạn")
    _limit(user.id)

    async def events() -> AsyncIterator[str]:
        try:
            async for event in coach_service.stream_chat(
                db, user, client, body.messages, body.tz_offset
            ):
                yield f"data: {json.dumps(event, ensure_ascii=False)}\n\n"
        except Exception:  # lỗi từ API Claude giữa chừng: báo cho app thay vì cắt ngang luồng
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
    _limit(user.id)
    try:
        return await coach_service.weekly_insight(db, user, client, tz_offset)
    except Exception:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, "Không tạo được nhận xét lúc này"
        ) from None
