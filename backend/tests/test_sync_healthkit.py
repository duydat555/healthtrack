from httpx import AsyncClient

from tests.helpers import auth_headers

URL = "/api/v1/sync/healthkit"

PAYLOAD = {
    "steps": [{"day": "2026-11-10", "steps": 8200}, {"day": "2026-11-11", "steps": 9100}],
    "sleep": [
        {
            "external_id": "sleep-1",
            "start_at": "2026-11-10T16:00:00Z",
            "end_at": "2026-11-10T23:30:00Z",
        }
    ],
    "weights": [{"external_id": "w-1", "weight_kg": 70.0, "logged_at": "2026-11-11T01:00:00Z"}],
}


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.post(URL, json=PAYLOAD)).status_code == 401


async def test_sync_creates_then_updates_without_duplicates(client: AsyncClient) -> None:
    h = await auth_headers(client, height_cm=175)
    first = (await client.post(URL, headers=h, json=PAYLOAD)).json()
    assert first == {
        "steps": {"created": 2, "updated": 0},
        "sleep": {"created": 1, "updated": 0},
        "weights": {"created": 1, "updated": 0},
    }
    again = (await client.post(URL, headers=h, json=PAYLOAD)).json()
    assert again["steps"] == {"created": 0, "updated": 2}
    assert again["sleep"] == {"created": 0, "updated": 1}
    assert again["weights"] == {"created": 0, "updated": 1}

    assert len((await client.get("/api/v1/steps", headers=h)).json()) == 2
    assert len((await client.get("/api/v1/sleep", headers=h)).json()) == 1
    weights = (await client.get("/api/v1/weights", headers=h)).json()
    assert len(weights) == 1
    assert weights[0]["bmi"] == 22.9  # 70 / 1.75^2


async def test_sync_overwrites_manual_steps_of_same_day(client: AsyncClient) -> None:
    h = await auth_headers(client)
    await client.post("/api/v1/steps", headers=h, json={"steps": 100, "day": "2026-11-10"})
    await client.post(URL, headers=h, json={"steps": [{"day": "2026-11-10", "steps": 8200}]})
    steps = (await client.get("/api/v1/steps", headers=h)).json()
    assert [s["steps"] for s in steps] == [8200]


async def test_sync_is_isolated_per_user(client: AsyncClient) -> None:
    a = await auth_headers(client, "a@example.com")
    b = await auth_headers(client, "b@example.com")
    await client.post(URL, headers=a, json=PAYLOAD)
    again = (await client.post(URL, headers=b, json=PAYLOAD)).json()
    assert again["sleep"]["created"] == 1  # cùng external_id nhưng người dùng khác
    assert len((await client.get("/api/v1/sleep", headers=a)).json()) == 1


async def test_rejects_invalid_payload(client: AsyncClient) -> None:
    h = await auth_headers(client)
    bad_sleep = {
        "sleep": [
            {
                "external_id": "x",
                "start_at": "2026-11-10T23:00:00Z",
                "end_at": "2026-11-10T22:00:00Z",
            }
        ]
    }
    assert (await client.post(URL, headers=h, json=bad_sleep)).status_code == 422
    negative = {"steps": [{"day": "2026-11-10", "steps": -1}]}
    assert (await client.post(URL, headers=h, json=negative)).status_code == 422
    assert (await client.post(URL, headers=h, json={})).status_code == 200
