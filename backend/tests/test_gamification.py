from datetime import UTC, datetime, timedelta

from httpx import AsyncClient

from tests.helpers import auth_headers

SUMMARY = "/api/v1/gamification/summary"
ACHIEVEMENTS = "/api/v1/gamification/achievements"


def _iso(days_ago: int, hour: int = 12) -> str:
    d = datetime.now(UTC).replace(hour=hour, minute=0, second=0, microsecond=0)
    return (d - timedelta(days=days_ago)).isoformat()


async def _water(client: AsyncClient, h: dict[str, str], ml: int, days_ago: int = 0) -> None:
    res = await client.post(
        "/api/v1/water", headers=h, json={"amount_ml": ml, "logged_at": _iso(days_ago)}
    )
    assert res.status_code == 201, res.text


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.get(SUMMARY)).status_code == 401
    assert (await client.get(ACHIEVEMENTS)).status_code == 401


async def test_empty_user_scores_zero(client: AsyncClient) -> None:
    h = await auth_headers(client)
    body = (await client.get(SUMMARY, headers=h)).json()
    assert body["score"] == 0
    assert body["streak"] == 0
    assert body["new_achievements"] == []
    assert body["challenge"] == {
        "code": "water_week",
        "title": "Uống đủ nước 5 ngày trong tuần",
        "progress": 0,
        "target": 5,
    }


async def test_score_and_first_log_badge(client: AsyncClient) -> None:
    h = await auth_headers(client)
    await _water(client, h, 2000)  # đủ mục tiêu nước mặc định, chưa có ngủ/bước chân
    body = (await client.get(SUMMARY, headers=h)).json()
    assert body["score"] == 33  # (100 + 0 + 0) / 3
    water = next(c for c in body["components"] if c["metric"] == "water")
    assert water["percent"] == 100.0
    assert set(body["new_achievements"]) == {"first_log", "water_goal"}
    # Lần gọi sau không trao lại
    assert (await client.get(SUMMARY, headers=h)).json()["new_achievements"] == []


async def test_goal_changes_target(client: AsyncClient) -> None:
    h = await auth_headers(client)
    await client.post(
        "/api/v1/goals",
        headers=h,
        json={"metric": "water", "period": "daily", "target_value": 1000},
    )
    await _water(client, h, 500)
    comp = (await client.get(SUMMARY, headers=h)).json()["components"]
    assert next(c for c in comp if c["metric"] == "water")["percent"] == 50.0


async def test_streak_counts_consecutive_days(client: AsyncClient) -> None:
    h = await auth_headers(client)
    for ago in (1, 2, 3):
        await _water(client, h, 2000, ago)
        await client.post("/api/v1/steps", headers=h, json={"steps": 8000, "day": _iso(ago)[:10]})
        await client.post(
            "/api/v1/sleep",
            headers=h,
            json={"start_at": _iso(ago + 1, 22), "end_at": _iso(ago, 6)},
        )
    body = (await client.get(SUMMARY, headers=h)).json()
    assert body["streak"] == 3  # hôm nay chưa đạt nên tính tới hôm qua
    assert "streak_3" in body["new_achievements"]
    assert body["challenge"]["progress"] == 3


async def test_achievements_list(client: AsyncClient) -> None:
    h = await auth_headers(client)
    await _water(client, h, 2500)
    items = (await client.get(ACHIEVEMENTS, headers=h)).json()
    assert len(items) == 8
    by_code = {i["code"]: i for i in items}
    assert by_code["water_goal"]["earned_at"] is not None
    assert by_code["streak_30"]["earned_at"] is None


async def test_achievements_are_per_user(client: AsyncClient) -> None:
    a = await auth_headers(client, "a@example.com")
    b = await auth_headers(client, "b@example.com")
    await _water(client, a, 2500)
    await client.get(SUMMARY, headers=a)
    items = (await client.get(ACHIEVEMENTS, headers=b)).json()
    assert all(i["earned_at"] is None for i in items)
