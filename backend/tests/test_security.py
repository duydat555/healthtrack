"""Kiểm thử bảo mật: JWT, cấu hình production và CORS."""

from datetime import UTC, datetime, timedelta

import pytest
from httpx import ASGITransport, AsyncClient
from jose import jwt
from pydantic import ValidationError

from app.core.config import DEFAULT_JWT_SECRET, Settings, settings
from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)
from app.main import app


def test_token_roundtrip() -> None:
    token = create_access_token(42)
    assert decode_access_token(token) == "42"


def test_extra_claims_cannot_override_security_claims() -> None:
    token = create_access_token(1, {"sub": "999", "type": "refresh", "role": "x"})
    assert decode_access_token(token) == "1"


def test_expired_token_is_rejected() -> None:
    payload = {"sub": "1", "type": "access", "exp": datetime.now(UTC) - timedelta(seconds=5)}
    token = jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
    assert decode_access_token(token) is None


def test_token_signed_with_wrong_secret_is_rejected() -> None:
    payload = {"sub": "1", "type": "access", "exp": datetime.now(UTC) + timedelta(minutes=5)}
    token = jwt.encode(payload, "khoa-khac-hoan-toan-khong-lien-quan", algorithm="HS256")
    assert decode_access_token(token) is None


def test_token_with_other_algorithm_is_rejected() -> None:
    payload = {"sub": "1", "type": "access", "exp": datetime.now(UTC) + timedelta(minutes=5)}
    token = jwt.encode(payload, settings.JWT_SECRET, algorithm="HS512")
    assert decode_access_token(token) is None


def test_non_access_and_incomplete_tokens_are_rejected() -> None:
    exp = datetime.now(UTC) + timedelta(minutes=5)
    for payload in (
        {"sub": "1", "type": "refresh", "exp": exp},  # sai loại
        {"type": "access", "exp": exp},  # thiếu sub
        {"sub": "1", "type": "access"},  # thiếu exp
    ):
        token = jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
        assert decode_access_token(token) is None


def test_garbage_token_is_rejected() -> None:
    assert decode_access_token("khong.phai.jwt") is None


def test_password_hash_is_salted_and_verifies() -> None:
    a, b = hash_password("mat-khau-1"), hash_password("mat-khau-1")
    assert a != b and a != "mat-khau-1"
    assert verify_password("mat-khau-1", a)
    assert not verify_password("sai", a)


def test_long_password_is_supported() -> None:
    long_password = "mat-khau-rat-dai-" * 20  # hơn 72 byte
    assert verify_password(long_password, hash_password(long_password))
    assert not verify_password(long_password + "x", hash_password(long_password))


def test_malformed_hash_returns_false_instead_of_raising() -> None:
    assert verify_password("abc", "khong-phai-bcrypt") is False


def test_production_rejects_default_or_short_jwt_secret() -> None:
    with pytest.raises(ValidationError):
        Settings(ENV="production", JWT_SECRET=DEFAULT_JWT_SECRET)
    with pytest.raises(ValidationError):
        Settings(ENV="production", JWT_SECRET="ngan")
    ok = Settings(ENV="production", JWT_SECRET="x" * 40, CORS_ORIGINS="https://app.example.com")
    assert ok.cors_origins_list == ["https://app.example.com"]


def test_production_rejects_wildcard_cors() -> None:
    with pytest.raises(ValidationError):
        Settings(ENV="production", JWT_SECRET="x" * 40, CORS_ORIGINS="*")


def test_development_keeps_defaults_usable() -> None:
    # development chấp nhận secret ngắn để chạy nhanh trên máy cá nhân
    assert Settings(ENV="development", JWT_SECRET="ngan").JWT_SECRET == "ngan"


async def _preflight(origin: str) -> dict[str, str]:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.options(
            "/api/v1/health",
            headers={"Origin": origin, "Access-Control-Request-Method": "GET"},
        )
    return dict(res.headers)


async def test_cors_allows_only_configured_origin() -> None:
    allowed = settings.cors_origins_list[0]
    assert (await _preflight(allowed)).get("access-control-allow-origin") == allowed
    assert "access-control-allow-origin" not in await _preflight("https://evil.example.com")
