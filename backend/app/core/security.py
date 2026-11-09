"""Tiện ích bảo mật: băm mật khẩu và tạo JWT.

Phần đăng ký/đăng nhập được triển khai trong issue Phase 1 (Backend).
"""

import base64
import hashlib
from datetime import UTC, datetime, timedelta
from typing import Any

import bcrypt
from jose import JWTError, jwt

from app.core.config import settings


def _prepare(password: str) -> bytes:
    """bcrypt chỉ nhận tối đa 72 byte; băm SHA-256 trước để mật khẩu dài không bị cắt hoặc lỗi."""
    return base64.b64encode(hashlib.sha256(password.encode()).digest())


def hash_password(password: str) -> str:
    return bcrypt.hashpw(_prepare(password), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(_prepare(plain), hashed.encode())
    except ValueError:  # hash trong CSDL sai định dạng
        return False


def create_access_token(subject: str | int, extra: dict[str, Any] | None = None) -> str:
    expire = datetime.now(UTC) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    now = datetime.now(UTC)
    # extra đặt trước để không ghi đè được các claim bảo mật bên dưới
    payload = {**(extra or {}), "sub": str(subject), "iat": now, "exp": expire, "type": "access"}
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(subject: str | int) -> str:
    now = datetime.now(UTC)
    expire = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {"sub": str(subject), "iat": now, "exp": expire, "type": "refresh"}
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str, expected_type: str) -> int | None:
    """Giải mã JWT, trả về user id nếu hợp lệ, chưa hết hạn và đúng loại; ngược lại None.

    Chỉ chấp nhận đúng thuật toán đã cấu hình (chặn đổi thuật toán/`none`) và bắt buộc có
    `exp` và `sub`. `expected_type` là `access` hoặc `refresh`, chặn dùng nhầm loại token.
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
            options={"require_exp": True, "require_sub": True},
        )
    except JWTError:
        return None
    if payload.get("type") != expected_type:
        return None
    try:
        return int(payload["sub"])
    except (KeyError, ValueError):
        return None


def decode_access_token(token: str) -> str | None:
    """Trả về `sub` dạng chuỗi nếu là access token hợp lệ, ngược lại None."""
    user_id = decode_token(token, "access")
    return None if user_id is None else str(user_id)
