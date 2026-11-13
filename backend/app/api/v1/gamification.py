from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.gamification import AchievementOut, GamificationSummary
from app.services import gamification as service

router = APIRouter(prefix="/gamification", tags=["gamification"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
TzOffset = Annotated[int, Query(ge=-720, le=840)]


@router.get("/summary", response_model=GamificationSummary)
async def summary(user: CurrentUser, db: DbSession, tz_offset: TzOffset = 0) -> GamificationSummary:
    """Health Score hôm nay, streak, thử thách tuần và huy hiệu vừa đạt."""
    return await service.build_summary(db, user.id, tz_offset)


@router.get("/achievements", response_model=list[AchievementOut])
async def achievements(
    user: CurrentUser, db: DbSession, tz_offset: TzOffset = 0
) -> list[AchievementOut]:
    """Toàn bộ huy hiệu, kèm thời điểm đạt (null nếu chưa đạt)."""
    return await service.list_achievements(db, user.id, tz_offset)
