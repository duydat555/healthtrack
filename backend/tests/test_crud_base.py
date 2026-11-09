"""Kiểm thử CRUDBase bằng model mẫu trên SQLite trong bộ nhớ."""

from collections.abc import AsyncGenerator

import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.crud.base import CRUDBase


class Note(Base):
    __tablename__ = "test_notes"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column()
    text: Mapped[str] = mapped_column()


class Shared(Base):
    __tablename__ = "test_shared"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column()


notes = CRUDBase(Note)
shared = CRUDBase(Shared)


@pytest.fixture
async def db() -> AsyncGenerator[AsyncSession, None]:
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with async_sessionmaker(engine, expire_on_commit=False)() as session:
        yield session
    await engine.dispose()


async def test_create_forces_owner(db: AsyncSession) -> None:
    note = await notes.create(db, {"text": "a", "user_id": 999}, owner_id=1)
    assert note.user_id == 1


async def test_list_only_returns_own_rows(db: AsyncSession) -> None:
    await notes.create(db, {"text": "của 1"}, owner_id=1)
    await notes.create(db, {"text": "của 2"}, owner_id=2)
    rows = await notes.list(db, owner_id=1)
    assert [n.text for n in rows] == ["của 1"]


async def test_cannot_read_update_delete_other_users_row(db: AsyncSession) -> None:
    note = await notes.create(db, {"text": "bí mật"}, owner_id=1)
    assert await notes.get(db, note.id, owner_id=2) is None
    assert await notes.update(db, note.id, {"text": "hack"}, owner_id=2) is None
    assert await notes.delete(db, note.id, owner_id=2) is False
    assert (await notes.get(db, note.id, owner_id=1)).text == "bí mật"  # type: ignore[union-attr]


async def test_update_and_delete_own_row(db: AsyncSession) -> None:
    note = await notes.create(db, {"text": "cũ"}, owner_id=1)
    updated = await notes.update(db, note.id, {"text": "mới", "user_id": 5}, owner_id=1)
    assert updated is not None and updated.text == "mới" and updated.user_id == 1
    assert await notes.delete(db, note.id, owner_id=1) is True
    assert await notes.get(db, note.id, owner_id=1) is None


async def test_missing_owner_id_is_rejected(db: AsyncSession) -> None:
    with pytest.raises(ValueError):
        await notes.list(db)


async def test_model_without_owner_needs_no_owner_id(db: AsyncSession) -> None:
    item = await shared.create(db, {"name": "chung"})
    assert (await shared.get(db, item.id)).name == "chung"  # type: ignore[union-attr]
