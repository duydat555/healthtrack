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


def decode_access_token(token: str) -> str | None:
    """Trả về `sub` (id người dùng) nếu token hợp lệ, ngược lại None.

    Chỉ chấp nhận đúng thuật toán đã cấu hình (chặn tấn công đổi thuật toán/`none`),
    bắt buộc có `exp` và `sub`, và chỉ nhận token loại `access` (không nhận refresh token).
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
    if payload.get("type") != "access":
        return None
    return str(payload["sub"])
