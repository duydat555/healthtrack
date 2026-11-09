from httpx import AsyncClient

from tests.helpers import auth_headers

SUMMARY = "/api/v1/stats/summary"
TREND = "/api/v1/stats/trend"
VN = 420


async def _water(client: AsyncClient, h: dict[str, str], ml: int, at: str) -> None:
    res = await client.post("/api/v1/water", headers=h, json={"amount_ml": ml, "logged_at": at})
    assert res.status_code == 201


async def test_summary_moves_late_utc_record_to_next_local_day(client: AsyncClient) -> None:
    h = await auth_headers(client)
    await _water(client, h, 250, "2026-03-09T23:30:00Z")  # 06:30 ngày 10/3 giờ Việt Nam

    utc = await client.get(SUMMARY, headers=h, params={"date": "2026-03-10"})
    assert utc.json()["water_ml"] == 0
    vn = await client.get(SUMMARY, headers=h, params={"date": "2026-03-10", "tz_offset": VN})
    assert vn.json()["water_ml"] == 250
    prev = await client.get(SUMMARY, headers=h, params={"date": "2026-03-09", "tz_offset": VN})
    assert prev.json()["water_ml"] == 0


async def test_negative_offset_shifts_to_previous_day(client: AsyncClient) -> None:
    h = await auth_headers(client)
    await _water(client, h, 300, "2026-03-10T03:00:00Z")  # 22:00 ngày 9/3 tại UTC-5
    res = await client.get(SUMMARY, headers=h, params={"date": "2026-03-09", "tz_offset": -300})
    assert res.json()["water_ml"] == 300


async def test_trend_buckets_by_local_day(client: AsyncClient) -> None:
    h = await auth_headers(client)
    await _water(client, h, 250, "2026-03-09T23:30:00Z")
    await _water(client, h, 100, "2026-03-10T10:00:00Z")
    base = {"metric": "water", "range": "7d", "date": "2026-03-10"}
    utc = {
        p["date"]: p["value"]
        for p in (await client.get(TREND, headers=h, params=base)).json()["points"]
    }
    assert utc["2026-03-09"] == 250 and utc["2026-03-10"] == 100
    res = await client.get(TREND, headers=h, params={**base, "tz_offset": VN})
    vn = {p["date"]: p["value"] for p in res.json()["points"]}
    assert vn["2026-03-10"] == 350
    assert vn["2026-03-09"] is None


async def test_sleep_and_weight_respect_offset(client: AsyncClient) -> None:
    h = await auth_headers(client)
    night = {"start_at": "2026-03-09T15:00:00Z", "end_at": "2026-03-09T23:00:00Z"}  # tỉnh 06:00 VN
    await client.post("/api/v1/sleep", headers=h, json=night)
    await client.post(
        "/api/v1/weights", headers=h, json={"weight_kg": 70, "logged_at": "2026-03-09T23:30:00Z"}
    )
    params = {"date": "2026-03-10", "tz_offset": VN}
    body = (await client.get(SUMMARY, headers=h, params=params)).json()
    assert body["sleep_minutes"] == 480
    assert body["weight"]["latest_kg"] == 70


async def test_goal_progress_uses_offset(client: AsyncClient) -> None:
    h = await auth_headers(client)
    goal = {"metric": "water", "period": "daily", "target_value": 500}
    await client.post("/api/v1/goals", headers=h, json=goal)
    await _water(client, h, 250, "2026-03-09T23:30:00Z")
    params = {"date": "2026-03-10", "tz_offset": VN}
    g = (await client.get(SUMMARY, headers=h, params=params)).json()["goals"][0]
    assert g["current_value"] == 250 and g["percent"] == 50.0


async def test_tz_offset_validated_and_default_is_utc(client: AsyncClient) -> None:
    h = await auth_headers(client)
    for bad in (-721, 841):
        res = await client.get(SUMMARY, headers=h, params={"tz_offset": bad})
        assert res.status_code == 422
        res = await client.get(TREND, headers=h, params={"metric": "water", "tz_offset": bad})
        assert res.status_code == 422
    assert (await client.get(SUMMARY, headers=h, params={"tz_offset": 840})).status_code == 200
    assert (await client.get(SUMMARY, headers=h)).status_code == 200
