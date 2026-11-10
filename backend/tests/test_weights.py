from httpx import AsyncClient

from app.services.weight import calculate_bmi
from tests.helpers import auth_headers

URL = "/api/v1/weights"


def test_calculate_bmi() -> None:
    assert calculate_bmi(70, 175) == 22.9
    assert calculate_bmi(70, None) is None
    assert calculate_bmi(70, 0) is None


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401
    assert (await client.post(URL, json={"weight_kg": 60})).status_code == 401


async def test_create_computes_bmi_from_profile_height(client: AsyncClient) -> None:
    h = await auth_headers(client, height_cm=175)
    res = await client.post(URL, headers=h, json={"weight_kg": 70})
    assert res.status_code == 201
    assert res.json()["bmi"] == 22.9


async def test_create_without_height_has_null_bmi(client: AsyncClient) -> None:
    h = await auth_headers(client)
    res = await client.post(URL, headers=h, json={"weight_kg": 70})
    assert res.status_code == 201
    assert res.json()["bmi"] is None


async def test_validation(client: AsyncClient) -> None:
    h = await auth_headers(client)
    assert (await client.post(URL, headers=h, json={"weight_kg": -1})).status_code == 422
    assert (await client.post(URL, headers=h, json={"weight_kg": 501})).status_code == 422
    assert (await client.post(URL, headers=h, json={})).status_code == 422


async def test_update_recomputes_bmi_and_delete(client: AsyncClient) -> None:
    h = await auth_headers(client, height_cm=175)
    created = (await client.post(URL, headers=h, json={"weight_kg": 70})).json()
    res = await client.patch(f"{URL}/{created['id']}", headers=h, json={"weight_kg": 80})
    assert res.status_code == 200
    assert res.json()["weight_kg"] == 80
    assert res.json()["bmi"] == 26.1
    assert (await client.delete(f"{URL}/{created['id']}", headers=h)).status_code == 204
    assert (await client.delete(f"{URL}/{created['id']}", headers=h)).status_code == 404


async def test_cannot_access_other_users_data(client: AsyncClient) -> None:
    h1 = await auth_headers(client, "an@example.com")
    h2 = await auth_headers(client, "binh@example.com")
    created = (await client.post(URL, headers=h1, json={"weight_kg": 70})).json()
    assert (await client.get(URL, headers=h2)).json() == []
    other = f"{URL}/{created['id']}"
    assert (await client.patch(other, headers=h2, json={"weight_kg": 1})).status_code == 404
    assert (await client.delete(other, headers=h2)).status_code == 404
    assert len((await client.get(URL, headers=h1)).json()) == 1


async def test_filter_by_range_and_paginate(client: AsyncClient) -> None:
    h = await auth_headers(client)
    for day in (1, 2, 3, 4, 5):
        await client.post(
            URL, headers=h, json={"weight_kg": 60 + day, "logged_at": f"2026-01-0{day}T08:00:00Z"}
        )
    res = await client.get(
        URL, headers=h, params={"from": "2026-01-02T00:00:00Z", "to": "2026-01-04T23:59:59Z"}
    )
    assert [r["weight_kg"] for r in res.json()] == [64, 63, 62]
    page = await client.get(URL, headers=h, params={"limit": 2, "offset": 1})
    assert [r["weight_kg"] for r in page.json()] == [64, 63]
    assert (await client.get(URL, headers=h, params={"limit": 0})).status_code == 422


async def test_update_and_delete_missing_weight_return_404(client: AsyncClient) -> None:
    h = await auth_headers(client)
    assert (await client.patch(f"{URL}/999", headers=h, json={"weight_kg": 70})).status_code == 404
    assert (await client.delete(f"{URL}/999", headers=h)).status_code == 404
