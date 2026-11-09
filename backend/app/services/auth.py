"""Nghiệp vụ xác thực: đăng ký tài khoản."""

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.crud.user import user_crud
from app.models.user import User
from app.schemas.user import UserCreate


class EmailAlreadyExistsError(Exception):
    """Email đã được đăng ký."""


async def register_user(db: AsyncSession, data: UserCreate) -> User:
    email = data.email.lower()
    if await user_crud.get_by_email(db, email) is not None:
        raise EmailAlreadyExistsError(email)
    try:
        return await user_crud.create(
            db,
            {
                "email": email,
                "password_hash": hash_password(data.password),
                "full_name": data.full_name,
            },
        )
    except IntegrityError as exc:  # hai request đăng ký cùng lúc
        await db.rollback()
        raise EmailAlreadyExistsError(email) from exc
