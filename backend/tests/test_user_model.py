import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.db import Base
from app.models import User


@pytest.fixture
async def db():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with async_sessionmaker(engine, expire_on_commit=False)() as session:
        yield session
    await engine.dispose()


async def test_create_user_sets_defaults(db: AsyncSession) -> None:
    user = User(email="a@example.com", password_hash="x", full_name="An")
    db.add(user)
    await db.commit()
    await db.refresh(user)
    assert user.id is not None
    assert user.is_active is True
    assert user.created_at is not None


async def test_email_must_be_unique(db: AsyncSession) -> None:
    db.add(User(email="a@example.com", password_hash="x", full_name="An"))
    await db.commit()
    db.add(User(email="a@example.com", password_hash="y", full_name="Bình"))
    with pytest.raises(IntegrityError):
        await db.commit()
