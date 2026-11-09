from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.stats import StatsSummary, StatsTrend
from app.services import stats as stats_service

router = APIRouter(prefix="/stats", tags=["stats"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
# Số phút lệch so với UTC của người dùng (VN = 420), từ UTC-12 đến UTC+14
TzOffset = Annotated[int, Query(ge=-720, le=840)]


@router.get("/summary", response_model=StatsSummary)
async def summary(
    user: CurrentUser,
    db: DbSession,
    day: Annotated[date | None, Query(alias="date")] = None,
    tz_offset: TzOffset = 0,
) -> StatsSummary:
    """Số liệu của một ngày theo múi giờ ``tz_offset`` (mặc định hôm nay) và tiến độ mục tiêu."""
    today = day or stats_service.local_today(tz_offset)
    return await stats_service.build_summary(db, user.id, today, tz_offset)


@router.get("/trend", response_model=StatsTrend)
async def trend(
    user: CurrentUser,
    db: DbSession,
    metric: Literal["weight", "water", "sleep", "steps", "calories"],
    range_: Annotated[Literal["7d", "30d", "90d"], Query(alias="range")] = "7d",
    end: Annotated[date | None, Query(alias="date")] = None,
    tz_offset: TzOffset = 0,
) -> StatsTrend:
    """Giá trị theo từng ngày của một chỉ số trong 7, 30 hoặc 90 ngày kết thúc ở ``date``."""
    end = end or stats_service.local_today(tz_offset)
    return await stats_service.build_trend(db, user.id, metric, range_, end, tz_offset)
