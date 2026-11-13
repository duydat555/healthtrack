"""Đồng bộ dữ liệu từ Apple Health. Gọi lại nhiều lần không tạo bản ghi trùng:
bước chân khóa theo (user, ngày), giấc ngủ và cân nặng khóa theo ``external_id`` của mẫu HealthKit.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sleep_log import SleepLog
from app.models.step_log import StepLog
from app.models.user import User
from app.models.weight_log import WeightLog
from app.schemas.sync import HealthKitSync, HealthKitSyncResult, SyncCount
from app.services.weight import calculate_bmi

SOURCE = "healthkit"


async def sync_healthkit(db: AsyncSession, user: User, data: HealthKitSync) -> HealthKitSyncResult:
    steps, sleep, weights = SyncCount(), SyncCount(), SyncCount()

    days = {s.day: s.steps for s in data.steps}  # trùng ngày trong cùng lô thì lấy bản cuối
    if days:
        rows = {
            r.day: r
            for r in (
                await db.execute(
                    select(StepLog).where(StepLog.user_id == user.id, StepLog.day.in_(days))
                )
            ).scalars()
        }
        for day, value in days.items():
            row = rows.get(day)
            if row is None:
                db.add(StepLog(user_id=user.id, day=day, steps=value, source=SOURCE))
                steps.created += 1
            else:
                row.steps, row.source = value, SOURCE
                steps.updated += 1

    sleep_items = {s.external_id: s for s in data.sleep}
    if sleep_items:
        rows = {
            r.external_id: r
            for r in (
                await db.execute(
                    select(SleepLog).where(
                        SleepLog.user_id == user.id, SleepLog.external_id.in_(sleep_items)
                    )
                )
            ).scalars()
        }
        for ext, item in sleep_items.items():
            row = rows.get(ext)
            if row is None:
                db.add(
                    SleepLog(
                        user_id=user.id,
                        start_at=item.start_at,
                        end_at=item.end_at,
                        source=SOURCE,
                        external_id=ext,
                    )
                )
                sleep.created += 1
            else:
                row.start_at, row.end_at = item.start_at, item.end_at
                sleep.updated += 1

    weight_items = {w.external_id: w for w in data.weights}
    if weight_items:
        rows = {
            r.external_id: r
            for r in (
                await db.execute(
                    select(WeightLog).where(
                        WeightLog.user_id == user.id, WeightLog.external_id.in_(weight_items)
                    )
                )
            ).scalars()
        }
        for ext, item in weight_items.items():
            bmi = calculate_bmi(item.weight_kg, user.height_cm)
            row = rows.get(ext)
            if row is None:
                db.add(
                    WeightLog(
                        user_id=user.id,
                        weight_kg=item.weight_kg,
                        bmi=bmi,
                        logged_at=item.logged_at,
                        source=SOURCE,
                        external_id=ext,
                    )
                )
                weights.created += 1
            else:
                row.weight_kg, row.bmi, row.logged_at = item.weight_kg, bmi, item.logged_at
                weights.updated += 1

    await db.commit()
    return HealthKitSyncResult(steps=steps, sleep=sleep, weights=weights)
