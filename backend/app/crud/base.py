"""Lớp CRUD generic: dùng lại cho mọi model, tự lọc theo chủ sở hữu (user_id)."""

from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import Base


class CRUDBase[ModelT: Base]:
    """CRUD bất đồng bộ cho một model.

    Với model thuộc về người dùng (có cột ``owner_field``), mọi thao tác đọc/sửa/xóa
    phải truyền ``owner_id`` để chỉ chạm vào dữ liệu của chính người đó. Truy cập bản ghi
    của người khác trả về ``None`` (API nên đổi thành 404, không lộ sự tồn tại).
    """

    def __init__(self, model: type[ModelT], owner_field: str | None = "user_id") -> None:
        self.model = model
        self.owner_field = owner_field if owner_field and hasattr(model, owner_field) else None

    def _scope(self, stmt: Any, owner_id: int | None) -> Any:
        if self.owner_field is None:
            return stmt
        if owner_id is None:
            raise ValueError(f"{self.model.__name__} cần owner_id để truy vấn")
        return stmt.where(getattr(self.model, self.owner_field) == owner_id)

    async def get(self, db: AsyncSession, id_: int, owner_id: int | None = None) -> ModelT | None:
        stmt = self._scope(select(self.model).where(self.model.id == id_), owner_id)  # type: ignore[attr-defined]
        return (await db.execute(stmt)).scalar_one_or_none()

    async def list(
        self, db: AsyncSession, owner_id: int | None = None, *, skip: int = 0, limit: int = 50
    ) -> list[ModelT]:
        stmt = self._scope(select(self.model), owner_id)
        stmt = stmt.order_by(self.model.id).offset(skip).limit(min(limit, 200))  # type: ignore[attr-defined]
        return list((await db.execute(stmt)).scalars().all())

    async def create(
        self, db: AsyncSession, data: dict[str, Any], owner_id: int | None = None
    ) -> ModelT:
        values = dict(data)
        if self.owner_field is not None:
            if owner_id is None:
                raise ValueError(f"{self.model.__name__} cần owner_id để tạo")
            values[self.owner_field] = owner_id  # luôn ghi đè, không tin dữ liệu client gửi
        obj = self.model(**values)
        db.add(obj)
        await db.commit()
        await db.refresh(obj)
        return obj

    async def update(
        self, db: AsyncSession, id_: int, data: dict[str, Any], owner_id: int | None = None
    ) -> ModelT | None:
        obj = await self.get(db, id_, owner_id)
        if obj is None:
            return None
        for key, value in data.items():
            if key not in ("id", self.owner_field):
                setattr(obj, key, value)
        await db.commit()
        await db.refresh(obj)
        return obj

    async def delete(self, db: AsyncSession, id_: int, owner_id: int | None = None) -> bool:
        obj = await self.get(db, id_, owner_id)
        if obj is None:
            return False
        await db.delete(obj)
        await db.commit()
        return True
