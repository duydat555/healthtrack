"""Nghiệp vụ ghi bữa ăn và tổng calories theo ngày địa phương của người dùng."""

from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models.meal_log import MealLog
from app.schemas.meal import MealCreate, MealUpdate

meal_crud = CRUDBase(MealLog)


async def create_meal(db: AsyncSession, user_id: int, data: MealCreate) -> MealLog:
    return await meal_crud.create(
        db,
        {
            "meal_type": data.meal_type,
            "name": data.name,
            "calories": data.calories,
            "logged_at": data.logged_at or datetime.now(UTC),
        },
        owner_id=user_id,
    )


async def list_meals(
    db: AsyncSession,
    user_id: int,
    start: datetime | None,
    end: datetime | None,
    *,
    skip: int,
    limit: int,
) -> list[MealLog]:
    return await meal_crud.list_in_range(
        db, user_id, "logged_at", start, end, skip=skip, limit=limit
    )


async def update_meal(
    db: AsyncSession, user_id: int, meal_id: int, data: MealUpdate
) -> MealLog | None:
    changes = data.model_dump(exclude_unset=True, exclude_none=True)
    return await meal_crud.update(db, meal_id, changes, owner_id=user_id)


async def delete_meal(db: AsyncSession, user_id: int, meal_id: int) -> bool:
    return await meal_crud.delete(db, meal_id, owner_id=user_id)


async def daily_calories(
    db: AsyncSession, user_id: int, day: date, tz_offset: int = 0
) -> int:
    start = datetime.combine(day, time.min, tzinfo=UTC) - timedelta(minutes=tz_offset)
    end = start + timedelta(days=1)
    stmt = select(func.coalesce(func.sum(MealLog.calories), 0)).where(
        MealLog.user_id == user_id,
        MealLog.logged_at >= start,
        MealLog.logged_at < end,
    )
    return int((await db.execute(stmt)).scalar_one())
