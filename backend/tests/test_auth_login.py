from datetime import UTC, datetime, timedelta

from httpx import AsyncClient
from jose import jwt

from app.core.config import settings
from app.core.security import decode_token

REG = {"email": "an@example.com", "password": "matkhau123", "full_name": "An"}
LOGIN = {"email": "an@example.com", "password": "matkhau123"}


async def _register(client: AsyncClient) -> None:
    assert (await client.post("/api/v1/auth/register", json=REG)).status_code == 201


async def test_login_returns_access_and_refresh(client: AsyncClient) -> None:
    await _register(client)
    res = await client.post("/api/v1/auth/login", json=LOGIN)
    assert res.status_code == 200
    body = res.json()
    assert decode_token(body["access_token"], "access") == 1
    assert decode_token(body["refresh_token"], "refresh") == 1
    assert body["token_type"] == "bearer"


async def test_login_wrong_password_returns_401(client: AsyncClient) -> None:
    await _register(client)
    res = await client.post("/api/v1/auth/login", json={**LOGIN, "password": "sai-mat-khau"})
    assert res.status_code == 401


async def test_login_unknown_email_returns_401(client: AsyncClient) -> None:
    res = await client.post("/api/v1/auth/login", json=LOGIN)
    assert res.status_code == 401


async def test_refresh_issues_new_tokens(client: AsyncClient) -> None:
    await _register(client)
    tokens = (await client.post("/api/v1/auth/login", json=LOGIN)).json()
    res = await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert res.status_code == 200
    assert decode_token(res.json()["access_token"], "access") == 1


async def test_refresh_rejects_access_token(client: AsyncClient) -> None:
    await _register(client)
    tokens = (await client.post("/api/v1/auth/login", json=LOGIN)).json()
    res = await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["access_token"]})
    assert res.status_code == 401


async def test_refresh_rejects_expired_and_garbage_token(client: AsyncClient) -> None:
    await _register(client)
    expired = jwt.encode(
        {"sub": "1", "type": "refresh", "exp": datetime.now(UTC) - timedelta(seconds=1)},
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM,
    )
    for token in (expired, "rac"):
        res = await client.post("/api/v1/auth/refresh", json={"refresh_token": token})
        assert res.status_code == 401
