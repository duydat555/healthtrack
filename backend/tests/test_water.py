from httpx import AsyncClient

from tests.helpers import auth_headers

URL = "/api/v1/water"


async def _add(client: AsyncClient, h: dict[str, str], ml: int, at: str) -> dict:
    res = await client.post(URL, headers=h, json={"amount_ml": ml, "logged_at": at})
    assert res.status_code == 201
    return res.json()


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401
    assert (await client.get(f"{URL}/total")).status_code == 401


async def test_crud_flow(client: AsyncClient) -> None:
    h = await auth_headers(client)
    created = await _add(client, h, 250, "2026-03-01T08:00:00Z")
    res = await client.patch(f"{URL}/{created['id']}", headers=h, json={"amount_ml": 300})
    assert res.json()["amount_ml"] == 300
    assert len((await client.get(URL, headers=h)).json()) == 1
    assert (await client.delete(f"{URL}/{created['id']}", headers=h)).status_code == 204
    assert (await client.get(URL, headers=h)).json() == []
    assert (await client.delete(f"{URL}/{created['id']}", headers=h)).status_code == 404


async def test_validation(client: AsyncClient) -> None:
    h = await auth_headers(client)
    for bad in ({"amount_ml": 0}, {"amount_ml": -5}, {"amount_ml": 99999}, {}):
        assert (await client.post(URL, headers=h, json=bad)).status_code == 422


async def test_daily_total_sums_only_that_day(client: AsyncClient) -> None:
    h = await auth_headers(client)
    await _add(client, h, 250, "2026-03-01T00:00:00Z")
    await _add(client, h, 500, "2026-03-01T23:59:59Z")
    await _add(client, h, 300, "2026-03-02T00:00:00Z")
    await _add(client, h, 700, "2026-02-28T23:59:59Z")
    res = await client.get(f"{URL}/total", headers=h, params={"date": "2026-03-01"})
    assert res.status_code == 200
    assert res.json() == {"date": "2026-03-01", "total_ml": 750}
    empty = await client.get(f"{URL}/total", headers=h, params={"date": "2025-01-01"})
    assert empty.json()["total_ml"] == 0


async def test_daily_total_excludes_other_users(client: AsyncClient) -> None:
    h1 = await auth_headers(client, "an@example.com")
    h2 = await auth_headers(client, "binh@example.com")
    created = await _add(client, h1, 250, "2026-03-01T08:00:00Z")
    res = await client.get(f"{URL}/total", headers=h2, params={"date": "2026-03-01"})
    assert res.json()["total_ml"] == 0
    assert (
        await client.patch(f"{URL}/{created['id']}", headers=h2, json={"amount_ml": 1})
    ).status_code == 404
    assert (await client.delete(f"{URL}/{created['id']}", headers=h2)).status_code == 404
