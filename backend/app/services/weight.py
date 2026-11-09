"""Nghiệp vụ cân nặng: tính BMI từ chiều cao trong hồ sơ."""

from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models.user import User
from app.models.weight_log import WeightLog
from app.schemas.weight import WeightCreate, WeightUpdate

weight_crud = CRUDBase(WeightLog)


def calculate_bmi(weight_kg: float, height_cm: float | None) -> float | None:
    """BMI = kg / m^2, làm tròn 1 chữ số; None nếu chưa có chiều cao."""
    if not height_cm or height_cm <= 0:
        return None
    return round(weight_kg / (height_cm / 100) ** 2, 1)


async def create_weight(db: AsyncSession, user: User, data: WeightCreate) -> WeightLog:
    return await weight_crud.create(
        db,
        {
            "weight_kg": data.weight_kg,
            "bmi": calculate_bmi(data.weight_kg, user.height_cm),
            "logged_at": data.logged_at or datetime.now(UTC),
        },
        owner_id=user.id,
    )


async def update_weight(
    db: AsyncSession, user: User, weight_id: int, data: WeightUpdate
) -> WeightLog | None:
    changes = data.model_dump(exclude_unset=True, exclude_none=True)
    if "weight_kg" in changes:
        changes["bmi"] = calculate_bmi(changes["weight_kg"], user.height_cm)
    return await weight_crud.update(db, weight_id, changes, owner_id=user.id)
