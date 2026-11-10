from httpx import AsyncClient

from tests.helpers import auth_headers

URL = "/api/v1/sleep"
NIGHT = {"start_at": "2026-03-01T22:00:00Z", "end_at": "2026-03-02T06:30:00Z", "quality": 4}


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401
    assert (await client.post(URL, json=NIGHT)).status_code == 401


async def test_create_returns_duration(client: AsyncClient) -> None:
    h = await auth_headers(client)
    res = await client.post(URL, headers=h, json=NIGHT)
    assert res.status_code == 201
    assert res.json()["duration_minutes"] == 510
    assert res.json()["quality"] == 4


async def test_rejects_end_before_or_equal_start(client: AsyncClient) -> None:
    h = await auth_headers(client)
    before = {"start_at": "2026-03-02T06:00:00Z", "end_at": "2026-03-01T22:00:00Z"}
    equal = {"start_at": "2026-03-02T06:00:00Z", "end_at": "2026-03-02T06:00:00Z"}
    for bad in (before, equal):
        res = await client.post(URL, headers=h, json=bad)
        assert res.status_code == 422
        assert res.json() == {"detail": "Giờ thức dậy phải sau giờ đi ngủ"}


async def test_quality_range(client: AsyncClient) -> None:
    h = await auth_headers(client)
    for q in (0, 6):
        assert (await client.post(URL, headers=h, json={**NIGHT, "quality": q})).status_code == 422
    no_quality = {k: v for k, v in NIGHT.items() if k != "quality"}
    assert (await client.post(URL, headers=h, json=no_quality)).status_code == 201


async def test_update_revalidates_range_and_duration(client: AsyncClient) -> None:
    h = await auth_headers(client)
    created = (await client.post(URL, headers=h, json=NIGHT)).json()
    item = f"{URL}/{created['id']}"
    ok = await client.patch(item, headers=h, json={"end_at": "2026-03-02T07:00:00Z"})
    assert ok.status_code == 200
    assert ok.json()["duration_minutes"] == 540
    bad = await client.patch(item, headers=h, json={"end_at": "2026-03-01T20:00:00Z"})
    assert bad.status_code == 422
    assert (await client.get(URL, headers=h)).json()[0]["duration_minutes"] == 540


async def test_delete_and_ownership(client: AsyncClient) -> None:
    h1 = await auth_headers(client, "an@example.com")
    h2 = await auth_headers(client, "binh@example.com")
    created = (await client.post(URL, headers=h1, json=NIGHT)).json()
    item = f"{URL}/{created['id']}"
    assert (await client.get(URL, headers=h2)).json() == []
    assert (await client.patch(item, headers=h2, json={"quality": 1})).status_code == 404
    assert (await client.delete(item, headers=h2)).status_code == 404
    assert (await client.delete(item, headers=h1)).status_code == 204
    assert (await client.delete(item, headers=h1)).status_code == 404


async def test_filter_and_paginate(client: AsyncClient) -> None:
    h = await auth_headers(client)
    for day in range(1, 6):
        start = f"2026-03-{day:02}T22:00:00Z"
        end = f"2026-03-{day + 1:02}T06:00:00Z"
        res = await client.post(
            URL, headers=h, json={"start_at": start, "end_at": end, "quality": day}
        )
        assert res.status_code == 201

    filtered = await client.get(
        URL,
        headers=h,
        params={"from": "2026-03-02T00:00:00Z", "to": "2026-03-04T23:59:59Z"},
    )
    assert [row["quality"] for row in filtered.json()] == [4, 3, 2]

    page = await client.get(URL, headers=h, params={"limit": 2, "offset": 1})
    assert [row["quality"] for row in page.json()] == [4, 3]
    assert (await client.get(URL, headers=h, params={"limit": 201})).status_code == 422
    assert (await client.get(URL, headers=h, params={"offset": -1})).status_code == 422


async def test_update_missing_sleep_returns_404(client: AsyncClient) -> None:
    h = await auth_headers(client)
    res = await client.patch(f"{URL}/999", headers=h, json={"quality": 3})
    assert res.status_code == 404
