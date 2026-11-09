from datetime import UTC, date, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.stats import StatsSummary
from app.services import stats as stats_service

router = APIRouter(prefix="/stats", tags=["stats"])
DbSession = Annotated[AsyncSession, Depends(get_db)]


@router.get("/summary", response_model=StatsSummary)
async def summary(
    user: CurrentUser, db: DbSession, day: Annotated[date | None, Query(alias="date")] = None
) -> StatsSummary:
    """Số liệu của một ngày (UTC, mặc định hôm nay) và tiến độ các mục tiêu đang hoạt động."""
    return await stats_service.build_summary(db, user.id, day or datetime.now(UTC).date())
