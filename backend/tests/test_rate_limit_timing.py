import logging

import pytest
from httpx import AsyncClient

from app.core.config import settings
from app.core.rate_limit import RateLimiter

LOGIN = "/api/v1/auth/login"
BODY = {"email": "an@example.com", "password": "sai-mat-khau"}


def test_limiter_blocks_after_max_and_reports_retry_after() -> None:
    limiter = RateLimiter(max_requests=2, window_seconds=60)
    assert limiter.hit("ip") == 0
    assert limiter.hit("ip") == 0
    assert 1 <= limiter.hit("ip") <= 61
    assert limiter.hit("other-ip") == 0  # khóa khác không bị ảnh hưởng


def test_limiter_allows_again_after_window(monkeypatch: pytest.MonkeyPatch) -> None:
    now = [1000.0]
    monkeypatch.setattr("app.core.rate_limit.time.monotonic", lambda: now[0])
    limiter = RateLimiter(max_requests=1, window_seconds=10)
    assert limiter.hit("ip") == 0
    assert limiter.hit("ip") > 0
    now[0] += 10
    assert limiter.hit("ip") == 0


async def test_login_rate_limited_with_429(client: AsyncClient) -> None:
    for _ in range(settings.LOGIN_RATE_LIMIT):
        assert (await client.post(LOGIN, json=BODY)).status_code == 401
    res = await client.post(LOGIN, json=BODY)
    assert res.status_code == 429
    assert int(res.headers["Retry-After"]) >= 1
    assert "detail" in res.json()


async def test_rate_limit_only_applies_to_login(client: AsyncClient) -> None:
    for _ in range(settings.LOGIN_RATE_LIMIT + 1):
        await client.post(LOGIN, json=BODY)
    assert (await client.get("/api/v1/health")).status_code == 200


async def test_response_has_process_time_header(client: AsyncClient) -> None:
    res = await client.get("/api/v1/health")
    assert float(res.headers["X-Process-Time-Ms"]) >= 0


async def test_slow_request_logs_warning(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    monkeypatch.setattr(settings, "SLOW_REQUEST_MS", -1)  # mọi request đều coi là chậm
    with caplog.at_level(logging.INFO, logger="app.timing"):
        await client.get("/api/v1/health")
    assert any(
        r.levelno == logging.WARNING and "/api/v1/health" in r.message for r in caplog.records
    )
