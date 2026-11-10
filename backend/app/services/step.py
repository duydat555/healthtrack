"""Nghiệp vụ ghi số bước theo ngày; mỗi người dùng có tối đa một bản ghi mỗi ngày."""

from datetime import date

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models.step_log import StepLog
from app.schemas.step import StepCreate, StepUpdate

step_crud = CRUDBase(StepLog)


class DuplicateStepDayError(Exception):
    """Người dùng đã có bản ghi bước chân cho ngày được yêu cầu."""


async def list_steps(
    db: AsyncSession,
    user_id: int,
    day_from: date | None,
    day_to: date | None,
    *,
    skip: int,
    limit: int,
) -> list[StepLog]:
    stmt = select(StepLog).where(StepLog.user_id == user_id)
    if day_from is not None:
        stmt = stmt.where(StepLog.day >= day_from)
    if day_to is not None:
        stmt = stmt.where(StepLog.day <= day_to)
    stmt = stmt.order_by(StepLog.day.desc(), StepLog.id.desc()).offset(skip).limit(limit)
    return list((await db.execute(stmt)).scalars().all())


async def upsert_step(db: AsyncSession, user_id: int, data: StepCreate) -> tuple[StepLog, bool]:
    stmt = select(StepLog).where(StepLog.user_id == user_id, StepLog.day == data.day)
    existing = (await db.execute(stmt)).scalar_one_or_none()
    if existing is not None:
        existing.steps = data.steps
        await db.commit()
        await db.refresh(existing)
        return existing, False

    try:
        row = await step_crud.create(
            db, {"steps": data.steps, "day": data.day}, owner_id=user_id
        )
        return row, True
    except IntegrityError:
        # The unique index also protects simultaneous requests for the same user and day.
        await db.rollback()
        existing = (await db.execute(stmt)).scalar_one_or_none()
        if existing is None:
            raise
        existing.steps = data.steps
        await db.commit()
        await db.refresh(existing)
        return existing, False


async def update_step(
    db: AsyncSession, user_id: int, step_id: int, data: StepUpdate
) -> StepLog | None:
    row = await step_crud.get(db, step_id, owner_id=user_id)
    if row is None:
        return None

    changes = data.model_dump(exclude_unset=True, exclude_none=True)
    new_day = changes.get("day")
    if new_day is not None and new_day != row.day:
        stmt = select(StepLog.id).where(
            StepLog.user_id == user_id, StepLog.day == new_day, StepLog.id != step_id
        )
        if (await db.execute(stmt)).scalar_one_or_none() is not None:
            raise DuplicateStepDayError

    return await step_crud.update(db, step_id, changes, owner_id=user_id)
