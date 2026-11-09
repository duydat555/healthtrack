"""Nghiệp vụ nước uống: ghi nhận và tổng lượng nước theo ngày (UTC)."""

from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models.water_log import WaterLog

water_crud = CRUDBase(WaterLog)


async def daily_total_ml(db: AsyncSession, user_id: int, day: date) -> int:
    start = datetime.combine(day, time.min, tzinfo=UTC)
    stmt = select(func.coalesce(func.sum(WaterLog.amount_ml), 0)).where(
        WaterLog.user_id == user_id,
        WaterLog.logged_at >= start,
        WaterLog.logged_at < start + timedelta(days=1),
    )
    return int((await db.execute(stmt)).scalar_one())
