"""Nghiệp vụ xác thực: đăng ký tài khoản."""

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.crud.user import user_crud
from app.models.user import User
from app.schemas.user import TokenPair, UserCreate


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


class InvalidCredentialsError(Exception):
    """Sai email hoặc mật khẩu."""


class InvalidTokenError(Exception):
    """Refresh token không hợp lệ hoặc đã hết hạn."""


def _issue_tokens(user_id: int) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(user_id), refresh_token=create_refresh_token(user_id)
    )


async def authenticate(db: AsyncSession, email: str, password: str) -> TokenPair:
    user = await user_crud.get_by_email(db, email)
    if user is None or not user.is_active or not verify_password(password, user.password_hash):
        raise InvalidCredentialsError
    return _issue_tokens(user.id)


async def refresh_tokens(db: AsyncSession, refresh_token: str) -> TokenPair:
    user_id = decode_token(refresh_token, "refresh")
    if user_id is None:
        raise InvalidTokenError
    user = await user_crud.get(db, user_id)
    if user is None or not user.is_active:
        raise InvalidTokenError
    return _issue_tokens(user.id)
