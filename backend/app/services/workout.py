"""Nghiệm vụ buổi tập ngoài trời: lưu theo id do app tạo, mọi truy vấn lọc theo chủ sở hữu."""

from datetime import datetime
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.workout import Workout
from app.schemas.workout import WorkoutIn, WorkoutRead, WorkoutSummary, as_utc


def _values(data: WorkoutIn) -> dict[str, Any]:
    """Chuyển body PUT thành cột của bảng; splits và points lưu JSON với khóa camelCase."""
    return {
        "version": data.v,
        "sport": data.sport,
        "title": data.title,
        "started_at": as_utc(data.started_at),
        "ended_at": as_utc(data.ended_at),
        "moving_seconds": data.moving_seconds,
        "distance_m": data.distance_m,
        "elevation_gain_m": data.elevation_gain_m,
        "avg_pace_sec_per_km": data.avg_pace_sec_per_km,
        "kcal": data.kcal,
        "splits": [s.model_dump(mode="json", by_alias=True) for s in data.splits],
        "polyline": data.polyline,
        "points": (
            None
            if data.points is None
            else [p.model_dump(mode="json", by_alias=True, exclude_none=True) for p in data.points]
        ),
    }


def to_summary(row: Workout) -> WorkoutSummary:
    return WorkoutSummary.model_validate(_row_dict(row))


def to_read(row: Workout) -> WorkoutRead:
    return WorkoutRead.model_validate({**_row_dict(row), "points": row.points})


def _row_dict(row: Workout) -> dict[str, Any]:
    return {
        "v": row.version,
        "id": row.workout_id,
        "sport": row.sport,
        "title": row.title,
        "started_at": row.started_at,
        "ended_at": row.ended_at,
        "moving_seconds": row.moving_seconds,
        "distance_m": row.distance_m,
        "elevation_gain_m": row.elevation_gain_m,
        "avg_pace_sec_per_km": row.avg_pace_sec_per_km,
        "kcal": row.kcal,
        "splits": row.splits,
        "polyline": row.polyline,
    }


async def _find(db: AsyncSession, user_id: int, workout_id: str) -> Workout | None:
    stmt = select(Workout).where(Workout.user_id == user_id, Workout.workout_id == workout_id)
    return (await db.execute(stmt)).scalar_one_or_none()


async def list_workouts(
    db: AsyncSession, user_id: int, *, limit: int, before: datetime | None
) -> list[Workout]:
    stmt = select(Workout).where(Workout.user_id == user_id)
    if before is not None:
        stmt = stmt.where(Workout.started_at < as_utc(before))
    stmt = stmt.order_by(Workout.started_at.desc(), Workout.id.desc()).limit(limit)
    return list((await db.execute(stmt)).scalars().all())


async def get_workout(db: AsyncSession, user_id: int, workout_id: str) -> Workout | None:
    return await _find(db, user_id, workout_id)


async def upsert_workout(db: AsyncSession, user_id: int, data: WorkoutIn) -> tuple[Workout, bool]:
    """Tạo hoặc thay thế theo id; gửi lại cùng id không nhân đôi bản ghi."""
    values = _values(data)
    existing = await _find(db, user_id, data.id)
    if existing is not None:
        for key, value in values.items():
            setattr(existing, key, value)
        await db.commit()
        await db.refresh(existing)
        return existing, False

    row = Workout(user_id=user_id, workout_id=data.id, **values)
    db.add(row)
    try:
        await db.commit()
    except IntegrityError:
        # Hai request cùng id đến gần nhau: chỉ số duy nhất giữ một bản, bản sau thành cập nhật.
        await db.rollback()
        existing = await _find(db, user_id, data.id)
        if existing is None:
            raise
        for key, value in values.items():
            setattr(existing, key, value)
        await db.commit()
        await db.refresh(existing)
        return existing, False
    await db.refresh(row)
    return row, True


async def delete_workout(db: AsyncSession, user_id: int, workout_id: str) -> bool:
    result = await db.execute(
        delete(Workout).where(Workout.user_id == user_id, Workout.workout_id == workout_id)
    )
    await db.commit()
    return result.rowcount > 0
