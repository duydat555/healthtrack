from httpx import AsyncClient

from tests.helpers import auth_headers

URL = "/api/v1/steps"


async def test_steps_require_authentication(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401
    assert (await client.post(URL, json={"steps": 1200, "day": "2026-05-01"})).status_code == 401


async def test_upsert_crud_and_day_range(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    first = await client.post(URL, headers=headers, json={"steps": 1200, "day": "2026-05-01"})
    assert first.status_code == 201
    first_row = first.json()
    assert first_row["steps"] == 1200
    assert first_row["day"] == "2026-05-01"

    updated_by_upsert = await client.post(
        URL, headers=headers, json={"steps": 2400, "day": "2026-05-01"}
    )
    assert updated_by_upsert.status_code == 200
    assert updated_by_upsert.json()["id"] == first_row["id"]
    assert updated_by_upsert.json()["steps"] == 2400

    second = await client.post(URL, headers=headers, json={"steps": 3000, "day": "2026-05-02"})
    assert second.status_code == 201

    listed = await client.get(URL, headers=headers)
    assert [row["day"] for row in listed.json()] == ["2026-05-02", "2026-05-01"]
    ranged = await client.get(
        URL, headers=headers, params={"from": "2026-05-01", "to": "2026-05-01"}
    )
    assert [row["id"] for row in ranged.json()] == [first_row["id"]]

    patched = await client.patch(
        f"{URL}/{first_row['id']}", headers=headers, json={"steps": 2600}
    )
    assert patched.status_code == 200
    assert patched.json()["steps"] == 2600

    deleted = await client.delete(f"{URL}/{first_row['id']}", headers=headers)
    assert deleted.status_code == 204
    assert [row["day"] for row in (await client.get(URL, headers=headers)).json()] == ["2026-05-02"]


async def test_upsert_is_scoped_to_user(client: AsyncClient) -> None:
    first_user = await auth_headers(client, "first@example.com")
    second_user = await auth_headers(client, "second@example.com")
    day = "2026-05-01"
    first = await client.post(URL, headers=first_user, json={"steps": 100, "day": day})
    second = await client.post(URL, headers=second_user, json={"steps": 200, "day": day})

    assert first.status_code == second.status_code == 201
    assert first.json()["id"] != second.json()["id"]
    assert (await client.get(URL, headers=first_user)).json()[0]["steps"] == 100
    assert (await client.get(URL, headers=second_user)).json()[0]["steps"] == 200


async def test_update_and_delete_cannot_access_another_users_record(client: AsyncClient) -> None:
    owner = await auth_headers(client, "owner@example.com")
    other = await auth_headers(client, "other@example.com")
    created = await client.post(URL, headers=owner, json={"steps": 500, "day": "2026-05-01"})
    step_id = created.json()["id"]

    assert (await client.get(URL, headers=other)).json() == []
    patch_other = await client.patch(
        f"{URL}/{step_id}", headers=other, json={"steps": 999}
    )
    assert patch_other.status_code == 404
    assert (await client.delete(f"{URL}/{step_id}", headers=other)).status_code == 404


async def test_validation_and_conflicting_day(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    for invalid in (
        {"steps": -1, "day": "2026-05-01"},
        {"steps": 100},
        {"steps": 100, "day": "invalid-date"},
    ):
        assert (await client.post(URL, headers=headers, json=invalid)).status_code == 422

    first = await client.post(URL, headers=headers, json={"steps": 100, "day": "2026-05-01"})
    second = await client.post(URL, headers=headers, json={"steps": 200, "day": "2026-05-02"})
    conflict = await client.patch(
        f"{URL}/{first.json()['id']}",
        headers=headers,
        json={"day": "2026-05-02"},
    )
    assert conflict.status_code == 409
    assert second.status_code == 201


async def test_reversed_date_range_and_missing_step_mutations(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    reversed_range = await client.get(
        URL, headers=headers, params={"from": "2026-05-02", "to": "2026-05-01"}
    )
    missing_update = await client.patch(f"{URL}/999", headers=headers, json={"steps": 10})
    missing_delete = await client.delete(f"{URL}/999", headers=headers)

    assert reversed_range.status_code == 422
    assert missing_update.status_code == 404
    assert missing_delete.status_code == 404
