"""Nghiệp vụ giấc ngủ: kiểm tra thời gian hợp lệ."""

from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models.sleep_log import SleepLog
from app.schemas.sleep import SleepCreate, SleepUpdate, as_utc

sleep_crud = CRUDBase(SleepLog)


class InvalidSleepRangeError(Exception):
    """Giờ thức dậy không sau giờ đi ngủ."""


def _check_range(start_at, end_at) -> None:  # type: ignore[no-untyped-def]
    if as_utc(end_at) <= as_utc(start_at):
        raise InvalidSleepRangeError


async def create_sleep(db: AsyncSession, user_id: int, data: SleepCreate) -> SleepLog:
    _check_range(data.start_at, data.end_at)
    return await sleep_crud.create(db, data.model_dump(), owner_id=user_id)


async def update_sleep(
    db: AsyncSession, user_id: int, sleep_id: int, data: SleepUpdate
) -> SleepLog | None:
    current = await sleep_crud.get(db, sleep_id, owner_id=user_id)
    if current is None:
        return None
    changes = data.model_dump(exclude_unset=True)
    if changes.get("start_at") is None:
        changes.pop("start_at", None)
    if changes.get("end_at") is None:
        changes.pop("end_at", None)
    _check_range(changes.get("start_at", current.start_at), changes.get("end_at", current.end_at))
    return await sleep_crud.update(db, sleep_id, changes, owner_id=user_id)
