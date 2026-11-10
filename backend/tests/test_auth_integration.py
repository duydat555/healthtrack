from httpx import AsyncClient

REGISTER = {
    "email": "qa-auth@example.com",
    "password": "matkhau123",
    "full_name": "QA Auth",
}


async def test_authentication_flow_uses_isolated_test_database(client: AsyncClient) -> None:
    register = await client.post("/api/v1/auth/register", json=REGISTER)
    assert register.status_code == 201
    assert register.json()["email"] == REGISTER["email"]

    duplicate = await client.post("/api/v1/auth/register", json=REGISTER)
    assert duplicate.status_code == 409

    invalid_login = await client.post(
        "/api/v1/auth/login", json={"email": REGISTER["email"], "password": "sai-mat-khau"}
    )
    assert invalid_login.status_code == 401

    unauthenticated = await client.get("/api/v1/users/me")
    assert unauthenticated.status_code == 401

    login = await client.post(
        "/api/v1/auth/login",
        json={"email": REGISTER["email"], "password": REGISTER["password"]},
    )
    assert login.status_code == 200
    tokens = login.json()
    assert tokens["token_type"] == "bearer"
    assert tokens["access_token"]
    assert tokens["refresh_token"]

    refresh = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert refresh.status_code == 200
    refreshed_tokens = refresh.json()
    assert refreshed_tokens["access_token"]
    assert refreshed_tokens["refresh_token"]

    profile = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {refreshed_tokens['access_token']}"},
    )
    assert profile.status_code == 200
    assert profile.json()["email"] == REGISTER["email"]
