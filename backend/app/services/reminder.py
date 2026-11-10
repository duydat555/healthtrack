from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models.reminder import Reminder
from app.schemas.reminder import ReminderCreate

reminder_crud = CRUDBase(Reminder)


async def list_reminders(
    db: AsyncSession, user_id: int, *, skip: int = 0, limit: int = 50
) -> list[Reminder]:
    stmt = (
        select(Reminder)
        .where(Reminder.user_id == user_id)
        .order_by(Reminder.at_time, Reminder.id)
        .offset(skip)
        .limit(min(limit, 200))
    )
    return list((await db.execute(stmt)).scalars().all())


async def create_reminder(db: AsyncSession, user_id: int, data: ReminderCreate) -> Reminder:
    return await reminder_crud.create(db, data.model_dump(), owner_id=user_id)
