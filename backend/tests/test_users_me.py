from httpx import AsyncClient

REG = {"email": "an@example.com", "password": "matkhau123", "full_name": "An"}


async def _auth_headers(client: AsyncClient, reg: dict[str, str] = REG) -> dict[str, str]:
    await client.post("/api/v1/auth/register", json=reg)
    res = await client.post(
        "/api/v1/auth/login", json={"email": reg["email"], "password": reg["password"]}
    )
    return {"Authorization": f"Bearer {res.json()['access_token']}"}


async def test_me_requires_token(client: AsyncClient) -> None:
    assert (await client.get("/api/v1/users/me")).status_code == 401
    assert (await client.patch("/api/v1/users/me", json={})).status_code == 401


async def test_me_rejects_bad_and_refresh_tokens(client: AsyncClient) -> None:
    res = await client.get("/api/v1/users/me", headers={"Authorization": "Bearer rac"})
    assert res.status_code == 401
    await client.post("/api/v1/auth/register", json=REG)
    tokens = (
        await client.post(
            "/api/v1/auth/login", json={"email": REG["email"], "password": REG["password"]}
        )
    ).json()
    res = await client.get(
        "/api/v1/users/me", headers={"Authorization": f"Bearer {tokens['refresh_token']}"}
    )
    assert res.status_code == 401


async def test_get_me_returns_profile(client: AsyncClient) -> None:
    headers = await _auth_headers(client)
    res = await client.get("/api/v1/users/me", headers=headers)
    assert res.status_code == 200
    assert res.json()["email"] == "an@example.com"
    assert "password_hash" not in res.json()


async def test_patch_me_updates_profile(client: AsyncClient) -> None:
    headers = await _auth_headers(client)
    res = await client.patch(
        "/api/v1/users/me",
        headers=headers,
        json={
            "full_name": "An Nguyễn",
            "birth_date": "2000-01-31",
            "gender": "male",
            "height_cm": 172.5,
        },
    )
    assert res.status_code == 200
    body = res.json()
    assert body["full_name"] == "An Nguyễn"
    assert body["birth_date"] == "2000-01-31"
    assert body["gender"] == "male"
    assert body["height_cm"] == 172.5
    # Cập nhật một phần giữ nguyên các trường còn lại
    res = await client.patch("/api/v1/users/me", headers=headers, json={"height_cm": 180})
    assert res.json()["full_name"] == "An Nguyễn"
    assert res.json()["height_cm"] == 180


async def test_patch_me_validates_input(client: AsyncClient) -> None:
    headers = await _auth_headers(client)
    for bad in ({"height_cm": -5}, {"gender": "xyz"}, {"birth_date": "khong-phai-ngay"}):
        res = await client.patch("/api/v1/users/me", headers=headers, json=bad)
        assert res.status_code == 422


async def test_patch_me_only_changes_own_profile(client: AsyncClient) -> None:
    h1 = await _auth_headers(client)
    other = {"email": "binh@example.com", "password": "matkhau123", "full_name": "Bình"}
    h2 = await _auth_headers(client, other)
    await client.patch("/api/v1/users/me", headers=h1, json={"full_name": "Đã đổi"})
    assert (await client.get("/api/v1/users/me", headers=h2)).json()["full_name"] == "Bình"
