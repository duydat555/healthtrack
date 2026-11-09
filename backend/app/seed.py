"""Seed dữ liệu demo sạch (hoàn toàn giả lập, không dùng dữ liệu sức khỏe thật).

Chạy: ``python -m app.seed`` (hoặc ``make seed``). Chạy lại nhiều lần an toàn: tài khoản demo
và dữ liệu của nó được xóa rồi tạo lại, không đụng tới người dùng khác.
"""

import asyncio
import random
import sys
from datetime import UTC, datetime, time, timedelta

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.db import SessionLocal
from app.core.security import hash_password
from app.models import Medication, MedicationLog, SleepLog, User, WaterLog, WeightLog

DEMO_EMAIL = "demo@healthtrack.example"
DEMO_PASSWORD = "demo12345"
DAYS = 30


async def _delete_demo_user(db: AsyncSession) -> None:
    user = (await db.execute(select(User).where(User.email == DEMO_EMAIL))).scalar_one_or_none()
    if user is None:
        return
    med_ids = select(Medication.id).where(Medication.user_id == user.id)
    await db.execute(delete(MedicationLog).where(MedicationLog.medication_id.in_(med_ids)))
    for model in (Medication, WeightLog, WaterLog, SleepLog):
        await db.execute(delete(model).where(model.user_id == user.id))
    await db.delete(user)
    await db.commit()


async def seed_demo(db: AsyncSession, today: datetime | None = None) -> User:
    """Tạo tài khoản demo cùng dữ liệu ``DAYS`` ngày gần nhất. Kết quả cố định (seed ngẫu nhiên)."""
    rng = random.Random(42)
    today = (today or datetime.now(UTC)).replace(hour=0, minute=0, second=0, microsecond=0)
    await _delete_demo_user(db)

    user = User(
        email=DEMO_EMAIL,
        password_hash=hash_password(DEMO_PASSWORD),
        full_name="Người dùng Demo",
        gender="other",
        height_cm=170.0,
    )
    db.add(user)
    await db.flush()

    weight = 68.0
    for offset in range(DAYS, -1, -1):
        day = today - timedelta(days=offset)
        if offset % 3 == 0:
            weight = round(weight + rng.uniform(-0.4, 0.3), 1)
            bmi = round(weight / 1.7**2, 1)
            db.add(
                WeightLog(
                    user_id=user.id,
                    weight_kg=weight,
                    bmi=bmi,
                    logged_at=datetime.combine(day, time(7, 0), tzinfo=UTC),
                )
            )
        for hour in (8, 11, 15, 19):
            db.add(
                WaterLog(
                    user_id=user.id,
                    amount_ml=rng.choice((200, 250, 300, 350, 500)),
                    logged_at=datetime.combine(day, time(hour, 0), tzinfo=UTC),
                )
            )
        bedtime = datetime.combine(day, time(22, 30), tzinfo=UTC) + timedelta(
            minutes=rng.randint(-30, 60)
        )
        db.add(
            SleepLog(
                user_id=user.id,
                start_at=bedtime,
                end_at=bedtime + timedelta(minutes=rng.randint(360, 540)),
                quality=rng.randint(2, 5),
            )
        )

    vitamin = Medication(
        user_id=user.id, name="Vitamin C", dosage="500mg", schedule="Mỗi sáng sau ăn"
    )
    omega = Medication(user_id=user.id, name="Omega-3", dosage="1 viên", schedule="Mỗi tối")
    db.add_all([vitamin, omega])
    await db.flush()
    for offset in range(14, -1, -1):
        day = today - timedelta(days=offset)
        db.add(
            MedicationLog(
                medication_id=vitamin.id,
                taken_at=datetime.combine(day, time(8, 30), tzinfo=UTC),
                taken=rng.random() > 0.15,
            )
        )
        db.add(
            MedicationLog(
                medication_id=omega.id,
                taken_at=datetime.combine(day, time(20, 0), tzinfo=UTC),
                taken=rng.random() > 0.25,
            )
        )

    await db.commit()
    await db.refresh(user)
    return user


async def main() -> None:
    if settings.ENV == "production" and "--force" not in sys.argv:
        sys.exit("Từ chối seed khi ENV=production. Thêm --force nếu thực sự cần (dữ liệu demo).")
    async with SessionLocal() as db:
        user = await seed_demo(db)
    print(f"Đã seed dữ liệu demo cho {user.email} (mật khẩu: {DEMO_PASSWORD})")


if __name__ == "__main__":
    asyncio.run(main())
