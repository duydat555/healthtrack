from httpx import AsyncClient

from tests.helpers import auth_headers

URL = "/api/v1/medications"


async def _create(client: AsyncClient, h: dict[str, str], name: str = "Vitamin C") -> dict:
    res = await client.post(URL, headers=h, json={"name": name, "dosage": "500mg"})
    assert res.status_code == 201
    return res.json()


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401
    assert (await client.post(f"{URL}/1/logs", json={})).status_code == 401


async def test_crud_flow(client: AsyncClient) -> None:
    h = await auth_headers(client)
    med = await _create(client, h)
    assert med["is_active"] is True
    res = await client.patch(
        f"{URL}/{med['id']}", headers=h, json={"schedule": "Sáng 8h", "is_active": False}
    )
    assert res.json()["schedule"] == "Sáng 8h"
    assert res.json()["is_active"] is False
    assert res.json()["name"] == "Vitamin C"
    assert len((await client.get(URL, headers=h)).json()) == 1
    assert (await client.delete(f"{URL}/{med['id']}", headers=h)).status_code == 204
    assert (await client.delete(f"{URL}/{med['id']}", headers=h)).status_code == 404


async def test_validation(client: AsyncClient) -> None:
    h = await auth_headers(client)
    assert (await client.post(URL, headers=h, json={"name": ""})).status_code == 422
    assert (await client.post(URL, headers=h, json={})).status_code == 422


async def test_add_and_list_logs(client: AsyncClient) -> None:
    h = await auth_headers(client)
    med = await _create(client, h)
    first = await client.post(
        f"{URL}/{med['id']}/logs", headers=h, json={"taken_at": "2026-03-01T08:00:00Z"}
    )
    assert first.status_code == 201
    assert first.json()["taken"] is True
    missed = await client.post(
        f"{URL}/{med['id']}/logs",
        headers=h,
        json={"taken_at": "2026-03-02T08:00:00Z", "taken": False},
    )
    assert missed.json()["taken"] is False
    now = await client.post(f"{URL}/{med['id']}/logs", headers=h, json={})
    assert now.status_code == 201
    logs = (await client.get(f"{URL}/{med['id']}/logs", headers=h)).json()
    assert len(logs) == 3
    assert logs[0]["id"] == now.json()["id"]  # mới nhất trước
    page = await client.get(
        f"{URL}/{med['id']}/logs", headers=h, params={"limit": 1, "offset": 1}
    )
    assert [log["id"] for log in page.json()] == [missed.json()["id"]]
    assert (
        await client.get(f"{URL}/{med['id']}/logs", headers=h, params={"limit": 0})
    ).status_code == 422


async def test_log_validation_and_missing_medication(client: AsyncClient) -> None:
    h = await auth_headers(client)
    med = await _create(client, h)
    invalid = await client.post(
        f"{URL}/{med['id']}/logs", headers=h, json={"taken_at": "not-a-timestamp"}
    )
    assert invalid.status_code == 422
    assert (await client.post(f"{URL}/999/logs", headers=h, json={})).status_code == 404
    assert (await client.get(f"{URL}/999/logs", headers=h)).status_code == 404


async def test_logs_unreachable_after_medication_deleted(client: AsyncClient) -> None:
    h = await auth_headers(client)
    med = await _create(client, h)
    await client.post(f"{URL}/{med['id']}/logs", headers=h, json={})
    await client.delete(f"{URL}/{med['id']}", headers=h)
    assert (await client.get(f"{URL}/{med['id']}/logs", headers=h)).status_code == 404


async def test_cannot_access_other_users_medication(client: AsyncClient) -> None:
    h1 = await auth_headers(client, "an@example.com")
    h2 = await auth_headers(client, "binh@example.com")
    med = await _create(client, h1)
    item = f"{URL}/{med['id']}"
    assert (await client.get(URL, headers=h2)).json() == []
    assert (await client.patch(item, headers=h2, json={"name": "x"})).status_code == 404
    assert (await client.delete(item, headers=h2)).status_code == 404
    assert (await client.post(f"{item}/logs", headers=h2, json={})).status_code == 404
    assert (await client.get(f"{item}/logs", headers=h2)).status_code == 404
