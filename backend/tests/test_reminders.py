from httpx import AsyncClient

from tests.helpers import auth_headers

URL = "/api/v1/reminders"


async def _create(client: AsyncClient, headers: dict[str, str], **body: object) -> dict:
    payload = {"kind": "water", "at_time": "08:30:00", "enabled": True, **body}
    response = await client.post(URL, headers=headers, json=payload)
    assert response.status_code == 201, response.text
    return response.json()


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401
    assert (await client.post(URL, json={})).status_code == 401


async def test_crud_flow_and_order(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    later = await _create(client, headers, at_time="20:00:00", kind="sleep")
    earlier = await _create(client, headers, at_time="08:00:00")
    assert earlier["enabled"] is True
    assert [r["id"] for r in (await client.get(URL, headers=headers)).json()] == [
        earlier["id"],
        later["id"],
    ]

    updated = await client.patch(
        f"{URL}/{earlier['id']}", headers=headers, json={"enabled": False, "at_time": "09:15:00"}
    )
    assert updated.status_code == 200
    assert updated.json()["enabled"] is False
    assert updated.json()["at_time"] == "09:15:00"

    assert (await client.delete(f"{URL}/{earlier['id']}", headers=headers)).status_code == 204
    assert (await client.get(URL, headers=headers)).json() == [later]
    assert (await client.delete(f"{URL}/{earlier['id']}", headers=headers)).status_code == 404


async def test_reminders_are_isolated_between_users(client: AsyncClient) -> None:
    owner = await auth_headers(client, "owner@example.com")
    other = await auth_headers(client, "other@example.com")
    reminder = await _create(client, owner)

    assert (await client.get(URL, headers=other)).json() == []
    assert (
        await client.patch(
            f"{URL}/{reminder['id']}", headers=other, json={"enabled": False}
        )
    ).status_code == 404
    assert (await client.delete(f"{URL}/{reminder['id']}", headers=other)).status_code == 404
    assert (await client.get(URL, headers=owner)).json()[0]["enabled"] is True


async def test_create_and_update_validation(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    for body in (
        {"kind": "unknown", "at_time": "08:00:00"},
        {"kind": "water", "at_time": "25:00:00"},
        {"kind": "water"},
    ):
        assert (await client.post(URL, headers=headers, json=body)).status_code == 422

    reminder = await _create(client, headers)
    empty_update = await client.patch(f"{URL}/{reminder['id']}", headers=headers, json={})
    assert empty_update.status_code == 422
    assert (
        await client.patch(f"{URL}/{reminder['id']}", headers=headers, json={"enabled": None})
    ).status_code == 422
    assert (
        await client.patch(f"{URL}/{reminder['id']}", headers=headers, json={"kind": "unknown"})
    ).status_code == 422
    missing = await client.patch(f"{URL}/999", headers=headers, json={"enabled": False})
    assert missing.status_code == 404


async def test_pagination_limits(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    for hour in ("07:00:00", "08:00:00", "09:00:00"):
        await _create(client, headers, at_time=hour)
    page = (await client.get(URL, headers=headers, params={"limit": 2, "offset": 1})).json()
    assert len(page) == 2
    assert [item["at_time"] for item in page] == ["08:00:00", "09:00:00"]
    assert (await client.get(URL, headers=headers, params={"limit": 0})).status_code == 422
