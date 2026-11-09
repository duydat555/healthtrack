from httpx import AsyncClient


async def auth_headers(
    client: AsyncClient, email: str = "an@example.com", height_cm: float | None = None
) -> dict[str, str]:
    """Đăng ký, đăng nhập và (tuỳ chọn) đặt chiều cao; trả header Authorization."""
    await client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "matkhau123", "full_name": "Test"},
    )
    res = await client.post("/api/v1/auth/login", json={"email": email, "password": "matkhau123"})
    headers = {"Authorization": f"Bearer {res.json()['access_token']}"}
    if height_cm is not None:
        await client.patch("/api/v1/users/me", headers=headers, json={"height_cm": height_cm})
    return headers
