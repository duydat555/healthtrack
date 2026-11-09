from httpx import AsyncClient

from tests.helpers import auth_headers

TREND = "/api/v1/stats/trend"


async def _water(client: AsyncClient, h: dict[str, str], ml: int, at: str) -> None:
    res = await client.post("/api/v1/water", headers=h, json={"amount_ml": ml, "logged_at": at})
    assert res.status_code == 201


def _params(metric: str, range_: str = "7d", date: str = "2026-03-10") -> dict[str, str]:
    return {"metric": metric, "range": range_, "date": date}


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.get(TREND, params={"metric": "water"})).status_code == 401


async def test_validates_params(client: AsyncClient) -> None:
    h = await auth_headers(client)
    assert (await client.get(TREND, headers=h)).status_code == 422
    assert (await client.get(TREND, headers=h, params=_params("khac"))).status_code == 422
    assert (await client.get(TREND, headers=h, params=_params("water", "14d"))).status_code == 422


async def test_each_range_returns_one_point_per_day(client: AsyncClient) -> None:
    h = await auth_headers(client)
    for range_, days in (("7d", 7), ("30d", 30), ("90d", 90)):
        body = (await client.get(TREND, headers=h, params=_params("water", range_))).json()
        assert len(body["points"]) == days
        assert body["to_date"] == "2026-03-10"
        assert body["points"][-1]["date"] == "2026-03-10"
        assert body["points"][0]["date"] == body["from_date"]
        assert all(p["value"] is None for p in body["points"])


async def test_water_grouped_by_day_with_gaps_as_null(client: AsyncClient) -> None:
    h = await auth_headers(client)
    await _water(client, h, 250, "2026-03-10T08:00:00Z")
    await _water(client, h, 500, "2026-03-10T20:00:00Z")
    await _water(client, h, 300, "2026-03-08T09:00:00Z")
    await _water(client, h, 999, "2026-03-03T09:00:00Z")  # trước khoảng 7 ngày
    body = (await client.get(TREND, headers=h, params=_params("water"))).json()
    values = {p["date"]: p["value"] for p in body["points"]}
    assert body["unit"] == "ml"
    assert values["2026-03-10"] == 750
    assert values["2026-03-08"] == 300
    assert values["2026-03-09"] is None
    assert "2026-03-03" not in values


async def test_weight_uses_last_record_of_day(client: AsyncClient) -> None:
    h = await auth_headers(client)
    for kg, at in ((71, "2026-03-10T06:00:00Z"), (70.4, "2026-03-10T21:00:00Z")):
        await client.post("/api/v1/weights", headers=h, json={"weight_kg": kg, "logged_at": at})
    body = (await client.get(TREND, headers=h, params=_params("weight"))).json()
    assert body["points"][-1]["value"] == 70.4


async def test_sleep_counts_on_wake_up_day(client: AsyncClient) -> None:
    h = await auth_headers(client)
    night = {"start_at": "2026-03-09T23:00:00Z", "end_at": "2026-03-10T07:00:00Z"}
    await client.post("/api/v1/sleep", headers=h, json=night)
    body = (await client.get(TREND, headers=h, params=_params("sleep"))).json()
    values = {p["date"]: p["value"] for p in body["points"]}
    assert values["2026-03-10"] == 480
    assert values["2026-03-09"] is None


async def test_steps_have_no_data_yet(client: AsyncClient) -> None:
    h = await auth_headers(client)
    body = (await client.get(TREND, headers=h, params=_params("steps"))).json()
    assert body["unit"] == "steps"
    assert all(p["value"] is None for p in body["points"])


async def test_only_own_data(client: AsyncClient) -> None:
    h1 = await auth_headers(client, "an@example.com")
    h2 = await auth_headers(client, "binh@example.com")
    await _water(client, h1, 250, "2026-03-10T08:00:00Z")
    body = (await client.get(TREND, headers=h2, params=_params("water"))).json()
    assert all(p["value"] is None for p in body["points"])
