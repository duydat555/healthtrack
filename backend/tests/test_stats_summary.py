from httpx import AsyncClient

from tests.helpers import auth_headers

SUMMARY = "/api/v1/stats/summary"
DAY = {"date": "2026-03-10"}


async def _post(client: AsyncClient, h: dict[str, str], path: str, body: dict) -> None:
    res = await client.post(f"/api/v1/{path}", headers=h, json=body)
    assert res.status_code == 201, res.text


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.get(SUMMARY)).status_code == 401


async def test_empty_summary(client: AsyncClient) -> None:
    h = await auth_headers(client)
    res = await client.get(SUMMARY, headers=h, params=DAY)
    assert res.status_code == 200
    assert res.json() == {
        "date": "2026-03-10",
        "weight": None,
        "water_ml": 0,
        "sleep_minutes": 0,
        "medications": {"taken": 0, "missed": 0},
        "goals": [],
    }


async def test_summary_for_today_only(client: AsyncClient) -> None:
    h = await auth_headers(client, height_cm=175)
    await _post(client, h, "water", {"amount_ml": 250, "logged_at": "2026-03-10T08:00:00Z"})
    await _post(client, h, "water", {"amount_ml": 500, "logged_at": "2026-03-10T12:00:00Z"})
    await _post(client, h, "water", {"amount_ml": 900, "logged_at": "2026-03-09T12:00:00Z"})
    # Ngủ 23:00 hôm trước đến 06:30 hôm nay = 450 phút, tính vào ngày thức dậy
    sleep = {"start_at": "2026-03-09T23:00:00Z", "end_at": "2026-03-10T06:30:00Z"}
    await _post(client, h, "sleep", sleep)
    await _post(client, h, "weights", {"weight_kg": 71, "logged_at": "2026-03-10T06:00:00Z"})
    await _post(client, h, "weights", {"weight_kg": 70, "logged_at": "2026-03-10T20:00:00Z"})
    med = (await client.post("/api/v1/medications", headers=h, json={"name": "Vitamin"})).json()
    logs = f"/api/v1/medications/{med['id']}/logs"
    await _post(client, h, logs[len("/api/v1/") :], {"taken_at": "2026-03-10T08:00:00Z"})
    miss = {"taken_at": "2026-03-10T20:00:00Z", "taken": False}
    await _post(client, h, logs[len("/api/v1/") :], miss)

    body = (await client.get(SUMMARY, headers=h, params=DAY)).json()
    assert body["water_ml"] == 750
    assert body["sleep_minutes"] == 450
    assert body["weight"]["latest_kg"] == 70
    assert body["weight"]["bmi"] == 22.9
    assert body["medications"] == {"taken": 1, "missed": 1}


async def test_goal_progress_percent(client: AsyncClient) -> None:
    h = await auth_headers(client)
    goal = {"metric": "water", "period": "daily", "target_value": 2000}
    assert (await client.post("/api/v1/goals", headers=h, json=goal)).status_code == 201
    await _post(client, h, "water", {"amount_ml": 1500, "logged_at": "2026-03-10T08:00:00Z"})
    goals = (await client.get(SUMMARY, headers=h, params=DAY)).json()["goals"]
    assert len(goals) == 1
    assert goals[0]["metric"] == "water"
    assert goals[0]["current_value"] == 1500
    assert goals[0]["percent"] == 75.0
    assert goals[0]["achieved"] is False
    await _post(client, h, "water", {"amount_ml": 1000, "logged_at": "2026-03-10T10:00:00Z"})
    goals = (await client.get(SUMMARY, headers=h, params=DAY)).json()["goals"]
    assert goals[0]["percent"] == 125.0
    assert goals[0]["achieved"] is True


async def test_weekly_goal_sums_last_7_days(client: AsyncClient) -> None:
    h = await auth_headers(client)
    goal = {"metric": "sleep", "period": "weekly", "target_value": 480}
    await client.post("/api/v1/goals", headers=h, json=goal)
    for day in ("04", "08", "10"):  # 3 đêm 600 phút trong 7 ngày
        sleep = {"start_at": f"2026-03-{day}T00:00:00Z", "end_at": f"2026-03-{day}T10:00:00Z"}
        await _post(client, h, "sleep", sleep)
    old = {"start_at": "2026-03-01T00:00:00Z", "end_at": "2026-03-01T10:00:00Z"}
    await _post(client, h, "sleep", old)  # ngoài cửa sổ 7 ngày
    g = (await client.get(SUMMARY, headers=h, params=DAY)).json()["goals"][0]
    assert g["current_value"] == 600  # trung bình mỗi đêm, bỏ qua đêm ngoài cửa sổ
    assert g["percent"] == 125.0
    assert g["achieved"] is True


async def test_weight_goal_has_no_percent(client: AsyncClient) -> None:
    h = await auth_headers(client)
    goal = {"metric": "weight", "period": "daily", "target_value": 65}
    await client.post("/api/v1/goals", headers=h, json=goal)
    await _post(client, h, "weights", {"weight_kg": 70, "logged_at": "2026-03-10T06:00:00Z"})
    g = (await client.get(SUMMARY, headers=h, params=DAY)).json()["goals"][0]
    assert g["current_value"] == 70
    assert g["percent"] is None and g["achieved"] is None


async def test_inactive_goals_and_other_users_excluded(client: AsyncClient) -> None:
    h1 = await auth_headers(client, "an@example.com")
    h2 = await auth_headers(client, "binh@example.com")
    goal = (
        await client.post(
            "/api/v1/goals",
            headers=h1,
            json={"metric": "water", "period": "daily", "target_value": 2000},
        )
    ).json()
    await _post(client, h1, "water", {"amount_ml": 500, "logged_at": "2026-03-10T08:00:00Z"})
    other = (await client.get(SUMMARY, headers=h2, params=DAY)).json()
    assert other["water_ml"] == 0 and other["goals"] == []
    await client.patch(f"/api/v1/goals/{goal['id']}", headers=h1, json={"is_active": False})
    assert (await client.get(SUMMARY, headers=h1, params=DAY)).json()["goals"] == []
