"""Regression checks for injection payloads against the isolated test API."""

from httpx import AsyncClient


async def test_sql_injection_email_is_rejected_by_validation(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "' OR 1=1 --@example.com", "password": "anything"},
    )

    assert response.status_code == 422


async def test_sql_injection_shaped_profile_value_is_stored_as_data(client: AsyncClient) -> None:
    payload = {
        "email": "sql-check@example.com",
        "password": "test-password-123",
        "full_name": "QA'); DROP TABLE users; --",
    }

    created = await client.post("/api/v1/auth/register", json=payload)

    assert created.status_code == 201
    assert created.json()["full_name"] == payload["full_name"]
    assert created.headers["content-type"].startswith("application/json")

    # A successful second write and login show the payload was treated as a value,
    # not executed as SQL that could alter the users table.
    second = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "after-sql-check@example.com",
            "password": "test-password-123",
            "full_name": "QA",
        },
    )
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": payload["email"], "password": payload["password"]},
    )

    assert second.status_code == 201
    assert login.status_code == 200


async def test_stored_xss_payload_remains_json_text(client: AsyncClient) -> None:
    payload = {
        "email": "xss-check@example.com",
        "password": "test-password-123",
        "full_name": '<script>alert("xss")</script>',
    }

    response = await client.post("/api/v1/auth/register", json=payload)

    assert response.status_code == 201
    assert response.headers["content-type"].startswith("application/json")
    assert response.json()["full_name"] == payload["full_name"]
