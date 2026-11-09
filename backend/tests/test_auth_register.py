from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models import User

PAYLOAD = {"email": "An@Example.com", "password": "matkhau123", "full_name": "An"}


async def test_register_returns_201_without_password(client: AsyncClient) -> None:
    res = await client.post("/api/v1/auth/register", json=PAYLOAD)
    assert res.status_code == 201
    body = res.json()
    assert body["email"] == "an@example.com"
    assert "password" not in body and "password_hash" not in body


async def test_register_stores_bcrypt_hash(
    client: AsyncClient, session_maker: async_sessionmaker[AsyncSession]
) -> None:
    await client.post("/api/v1/auth/register", json=PAYLOAD)
    async with session_maker() as db:
        user = (await db.execute(select(User))).scalar_one()
    assert user.password_hash != PAYLOAD["password"]
    assert user.password_hash.startswith("$2")


async def test_register_duplicate_email_returns_409(client: AsyncClient) -> None:
    await client.post("/api/v1/auth/register", json=PAYLOAD)
    res = await client.post("/api/v1/auth/register", json={**PAYLOAD, "email": "an@example.com"})
    assert res.status_code == 409
    assert res.json() == {"detail": "Email đã được đăng ký"}


async def test_register_rejects_short_password_and_bad_email(client: AsyncClient) -> None:
    short = await client.post("/api/v1/auth/register", json={**PAYLOAD, "password": "123"})
    bad = await client.post("/api/v1/auth/register", json={**PAYLOAD, "email": "khong-phai-email"})
    assert short.status_code == 422
    assert bad.status_code == 422
