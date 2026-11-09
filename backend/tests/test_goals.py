from httpx import AsyncClient

from tests.helpers import auth_headers

URL = "/api/v1/goals"


async def _create(client: AsyncClient, h: dict[str, str], **body: object) -> dict:
    payload = {"metric": "water", "period": "daily", "target_value": 2000, **body}
    res = await client.post(URL, headers=h, json=payload)
    assert res.status_code == 201, res.text
    return res.json()


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401
    assert (await client.post(URL, json={})).status_code == 401


async def test_crud_flow(client: AsyncClient) -> None:
    h = await auth_headers(client)
    goal = await _create(client, h)
    assert goal["is_active"] is True and goal["unit"] == "ml" and goal["period"] == "daily"

    res = await client.patch(
        f"{URL}/{goal['id']}", headers=h, json={"target_value": 2500, "period": "weekly"}
    )
    assert res.status_code == 200
    assert res.json()["target_value"] == 2500 and res.json()["period"] == "weekly"

    assert len((await client.get(URL, headers=h)).json()) == 1
    assert (await client.delete(f"{URL}/{goal['id']}", headers=h)).status_code == 204
    assert (await client.get(URL, headers=h)).json() == []
    assert (await client.delete(f"{URL}/{goal['id']}", headers=h)).status_code == 404


async def test_one_active_goal_per_metric(client: AsyncClient) -> None:
    h = await auth_headers(client)
    first = await _create(client, h, metric="steps", target_value=10000)
    dup = await client.post(URL, headers=h, json={"metric": "steps", "target_value": 8000})
    assert dup.status_code == 409

    # chỉ số khác vẫn tạo được
    await _create(client, h, metric="sleep", target_value=480)

    # tắt mục tiêu cũ thì tạo được mục tiêu mới
    await client.patch(f"{URL}/{first['id']}", headers=h, json={"is_active": False})
    second = await _create(client, h, metric="steps", target_value=8000)

    # bật lại mục tiêu cũ khi đã có mục tiêu đang hoạt động khác thì bị từ chối
    res = await client.patch(f"{URL}/{first['id']}", headers=h, json={"is_active": True})
    assert res.status_code == 409
    active = (
        await client.get(URL, headers=h, params={"metric": "steps", "is_active": "true"})
    ).json()
    assert [g["id"] for g in active] == [second["id"]]


async def test_other_users_may_have_same_metric(client: AsyncClient) -> None:
    h1 = await auth_headers(client, "a@example.com")
    h2 = await auth_headers(client, "b@example.com")
    await _create(client, h1)
    await _create(client, h2)


async def test_cannot_access_other_users_goal(client: AsyncClient) -> None:
    h1 = await auth_headers(client, "a@example.com")
    h2 = await auth_headers(client, "b@example.com")
    goal = await _create(client, h1)
    url = f"{URL}/{goal['id']}"
    assert (await client.get(URL, headers=h2)).json() == []
    assert (await client.patch(url, headers=h2, json={"target_value": 1})).status_code == 404
    assert (await client.delete(url, headers=h2)).status_code == 404
    assert (await client.get(URL, headers=h1)).json()[0]["target_value"] == 2000


async def test_validation(client: AsyncClient) -> None:
    h = await auth_headers(client)
    for body in (
        {"metric": "khong-co", "target_value": 1},
        {"metric": "water", "period": "year", "target_value": 1},
        {"metric": "water", "target_value": 0},
        {"metric": "water", "target_value": -5},
        {"metric": "weight", "target_value": 600},  # vượt ngưỡng 500 kg
        {"metric": "sleep", "target_value": 2000},  # vượt 1440 phút
        {"target_value": 1},  # thiếu metric
    ):
        assert (await client.post(URL, headers=h, json=body)).status_code == 422, body


async def test_update_validates_range_and_cannot_change_metric(client: AsyncClient) -> None:
    h = await auth_headers(client)
    goal = await _create(client, h, metric="weight", target_value=65)
    url = f"{URL}/{goal['id']}"
    assert (await client.patch(url, headers=h, json={"target_value": 900})).status_code == 422
    res = await client.patch(url, headers=h, json={"metric": "water", "target_value": 60})
    assert res.json()["metric"] == "weight" and res.json()["target_value"] == 60


async def test_filter_by_metric_and_pagination(client: AsyncClient) -> None:
    h = await auth_headers(client)
    for metric, value in (("water", 2000), ("steps", 10000), ("sleep", 480)):
        await _create(client, h, metric=metric, target_value=value)
    only = (await client.get(URL, headers=h, params={"metric": "steps"})).json()
    assert [g["metric"] for g in only] == ["steps"]
    page = (await client.get(URL, headers=h, params={"limit": 2})).json()
    assert len(page) == 2
