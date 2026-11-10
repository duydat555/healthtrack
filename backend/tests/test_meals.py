from httpx import AsyncClient

from tests.helpers import auth_headers

URL = "/api/v1/meals"


async def _create(
    client: AsyncClient,
    headers: dict[str, str],
    *,
    meal_type: str = "breakfast",
    name: str = "Yến mạch",
    calories: int = 250,
    logged_at: str = "2026-05-01T08:00:00Z",
) -> dict:
    response = await client.post(
        URL,
        headers=headers,
        json={
            "meal_type": meal_type,
            "name": name,
            "calories": calories,
            "logged_at": logged_at,
        },
    )
    assert response.status_code == 201
    return response.json()


async def test_meals_require_authentication(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401
    assert (await client.get(f"{URL}/total")).status_code == 401
    assert (
        await client.post(
            URL,
            json={"meal_type": "lunch", "name": "Cơm", "calories": 500},
        )
    ).status_code == 401


async def test_meal_crud_and_range_pagination(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    first = await _create(client, headers)
    second = await _create(
        client,
        headers,
        meal_type="snack",
        name="Táo",
        calories=80,
        logged_at="2026-05-02T08:00:00Z",
    )

    listed = await client.get(URL, headers=headers, params={"limit": 1})
    assert len(listed.json()) == 1
    assert listed.json()[0]["id"] == second["id"]
    ranged = await client.get(
        URL,
        headers=headers,
        params={"from": "2026-05-01T00:00:00Z", "to": "2026-05-01T23:59:59Z"},
    )
    assert [meal["id"] for meal in ranged.json()] == [first["id"]]

    updated = await client.patch(
        f"{URL}/{first['id']}",
        headers=headers,
        json={"meal_type": "lunch", "name": "Cơm gà", "calories": 620},
    )
    assert updated.status_code == 200
    assert updated.json()["meal_type"] == "lunch"
    assert updated.json()["name"] == "Cơm gà"
    assert updated.json()["calories"] == 620

    deleted = await client.delete(f"{URL}/{first['id']}", headers=headers)
    assert deleted.status_code == 204
    assert (await client.get(URL, headers=headers)).json()[0]["id"] == second["id"]
    assert (await client.delete(f"{URL}/{first['id']}", headers=headers)).status_code == 404


async def test_daily_calories_respect_user_timezone(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    await _create(client, headers, calories=999, logged_at="2026-04-30T16:59:59Z")
    await _create(client, headers, calories=120, logged_at="2026-04-30T17:00:00Z")
    await _create(client, headers, calories=350, logged_at="2026-05-01T16:59:59Z")
    await _create(client, headers, calories=777, logged_at="2026-05-01T17:00:00Z")

    total = await client.get(
        f"{URL}/total", headers=headers, params={"date": "2026-05-01", "tz_offset": 420}
    )
    assert total.status_code == 200
    assert total.json() == {"date": "2026-05-01", "total_calories": 470}

    empty = await client.get(
        f"{URL}/total", headers=headers, params={"date": "2025-01-01"}
    )
    assert empty.json() == {"date": "2025-01-01", "total_calories": 0}


async def test_meal_data_and_daily_total_are_user_scoped(client: AsyncClient) -> None:
    owner = await auth_headers(client, "owner@example.com")
    other = await auth_headers(client, "other@example.com")
    meal = await _create(client, owner, calories=420)

    assert (await client.get(URL, headers=other)).json() == []
    total = await client.get(
        f"{URL}/total", headers=other, params={"date": "2026-05-01", "tz_offset": 0}
    )
    assert total.json()["total_calories"] == 0
    patch_other = await client.patch(
        f"{URL}/{meal['id']}", headers=other, json={"calories": 1}
    )
    assert patch_other.status_code == 404
    assert (await client.delete(f"{URL}/{meal['id']}", headers=other)).status_code == 404


async def test_meal_input_validation(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    for payload in (
        {"meal_type": "midnight", "name": "Ăn khuya", "calories": 100},
        {"meal_type": "lunch", "name": "Cơm", "calories": -1},
        {"meal_type": "lunch", "name": "", "calories": 100},
        {"meal_type": "lunch", "calories": 100},
    ):
        assert (await client.post(URL, headers=headers, json=payload)).status_code == 422

    created = await _create(client, headers)
    invalid_patch = await client.patch(
        f"{URL}/{created['id']}", headers=headers, json={"calories": -10}
    )
    assert invalid_patch.status_code == 422
