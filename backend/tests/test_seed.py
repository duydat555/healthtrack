from datetime import UTC, datetime

from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models import MedicationLog, SleepLog, User, WaterLog, WeightLog
from app.seed import DAYS, DEMO_EMAIL, DEMO_PASSWORD, seed_demo
from tests.helpers import auth_headers

NOW = datetime(2026, 11, 9, 12, 0, tzinfo=UTC)


async def _count(db: AsyncSession, model: type) -> int:
    return (await db.execute(select(func.count()).select_from(model))).scalar_one()


async def test_seed_creates_demo_data(session_maker: async_sessionmaker[AsyncSession]) -> None:
    async with session_maker() as db:
        user = await seed_demo(db, NOW)
        assert user.email == DEMO_EMAIL
        assert await _count(db, WaterLog) == 4 * (DAYS + 1)
        assert await _count(db, SleepLog) == DAYS + 1
        assert await _count(db, WeightLog) == DAYS // 3 + 1
        assert await _count(db, MedicationLog) == 30


async def test_seed_is_idempotent_and_keeps_other_users(
    session_maker: async_sessionmaker[AsyncSession],
) -> None:
    async with session_maker() as db:
        db.add(User(email="khac@example.com", password_hash="x", full_name="Khác"))
        await db.commit()
        await seed_demo(db, NOW)
        await seed_demo(db, NOW)
        assert await _count(db, User) == 2
        assert await _count(db, WaterLog) == 4 * (DAYS + 1)


async def test_demo_user_can_login_and_read_data(
    client: AsyncClient, session_maker: async_sessionmaker[AsyncSession]
) -> None:
    async with session_maker() as db:
        await seed_demo(db)
    res = await client.post(
        "/api/v1/auth/login", json={"email": DEMO_EMAIL, "password": DEMO_PASSWORD}
    )
    assert res.status_code == 200
    headers = {"Authorization": f"Bearer {res.json()['access_token']}"}
    assert len((await client.get("/api/v1/weights", headers=headers)).json()) > 0
    assert len((await client.get("/api/v1/medications", headers=headers)).json()) == 2
    # Người dùng khác không thấy dữ liệu demo
    other = await auth_headers(client, "khac@example.com")
    assert (await client.get("/api/v1/weights", headers=other)).json() == []
