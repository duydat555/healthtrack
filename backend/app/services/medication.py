"""Nghiệp vụ thuốc: nhật ký uống thuốc chỉ ghi được cho thuốc của chính người dùng."""

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models.medication import Medication, MedicationLog
from app.schemas.medication import MedicationLogCreate

medication_crud = CRUDBase(Medication)
# MedicationLog không có user_id; quyền sở hữu được kiểm tra qua Medication
log_crud = CRUDBase(MedicationLog, owner_field=None)


async def add_log(
    db: AsyncSession, user_id: int, medication_id: int, data: MedicationLogCreate
) -> MedicationLog | None:
    if await medication_crud.get(db, medication_id, owner_id=user_id) is None:
        return None
    return await log_crud.create(
        db,
        {
            "medication_id": medication_id,
            "taken_at": data.taken_at or datetime.now(UTC),
            "taken": data.taken,
        },
    )


async def list_logs(
    db: AsyncSession, user_id: int, medication_id: int, *, skip: int = 0, limit: int = 50
) -> list[MedicationLog] | None:
    if await medication_crud.get(db, medication_id, owner_id=user_id) is None:
        return None
    stmt = (
        select(MedicationLog)
        .where(MedicationLog.medication_id == medication_id)
        .order_by(MedicationLog.taken_at.desc(), MedicationLog.id.desc())
        .offset(skip)
        .limit(limit)
    )
    return list((await db.execute(stmt)).scalars().all())
