import json
from pathlib import Path

import pytest
from httpx import AsyncClient

from tests.helpers import auth_headers

URL = "/api/v1/workouts"
FIXTURES = Path(__file__).resolve().parents[2] / "mobile" / "test" / "fixtures" / "workouts"


def workout(wid: str = "run-1", started: str = "2026-11-21T22:30:00Z", **extra) -> dict:
    body = {
        "v": 1,
        "id": wid,
        "sport": "run",
        "title": "Chạy ven sông Hàn",
        "startedAt": started,
        "endedAt": "2026-11-21T22:58:20Z",
        "movingSeconds": 1670.0,
        "distanceM": 5190.12,
        "elevationGainM": 12.3,
        "avgPaceSecPerKm": 321.77,
        "kcal": 337.36,
        "splits": [
            {
                "index": 1,
                "distanceM": 1000,
                "seconds": 322.4,
                "paceSecPerKm": 322.4,
                "elevationDeltaM": 1.8,
            }
        ],
        "polyline": "_p~iF~ps|U_ulLnnqC",
        "points": [
            {"lat": 16.06071, "lon": 108.22652, "t": "2026-11-21T22:30:00Z", "alt": 8.1},
            {"lat": 16.0608, "lon": 108.2266, "t": "2026-11-21T22:30:05Z", "speed": 3.0, "seg": 1},
        ],
    }
    body.update(extra)
    return body


async def test_workouts_require_authentication(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401
    assert (await client.put(f"{URL}/run-1", json=workout())).status_code == 401
    assert (await client.delete(f"{URL}/run-1")).status_code == 401


async def test_put_creates_then_replaces_without_duplicating(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    created = await client.put(f"{URL}/run-1", headers=headers, json=workout())
    assert created.status_code == 201
    body = created.json()
    assert body["id"] == "run-1"
    assert body["startedAt"].startswith("2026-11-21T22:30:00")
    assert body["distanceM"] == 5190.12
    assert body["splits"][0]["paceSecPerKm"] == 322.4
    assert len(body["points"]) == 2

    again = await client.put(
        f"{URL}/run-1", headers=headers, json=workout(title="Chạy buổi tối", distanceM=5200)
    )
    assert again.status_code == 200
    assert again.json()["title"] == "Chạy buổi tối"
    listed = (await client.get(URL, headers=headers)).json()
    assert [w["id"] for w in listed] == ["run-1"]
    assert listed[0]["distanceM"] == 5200


async def test_list_omits_points_and_detail_includes_them(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    await client.put(f"{URL}/run-1", headers=headers, json=workout())
    listed = (await client.get(URL, headers=headers)).json()
    assert "points" not in listed[0] or listed[0]["points"] is None
    detail = (await client.get(f"{URL}/run-1", headers=headers)).json()
    assert detail["points"][1]["seg"] == 1
    assert detail["points"][0]["alt"] == 8.1


async def test_list_is_newest_first_with_limit_and_before(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    starts = {
        "a": "2026-11-20T06:00:00Z",
        "b": "2026-11-21T06:00:00Z",
        "c": "2026-11-22T06:00:00Z",
    }
    for wid, started in starts.items():
        await client.put(
            f"{URL}/{wid}",
            headers=headers,
            json=workout(wid, started, endedAt="2026-11-23T00:00:00Z"),
        )

    assert [w["id"] for w in (await client.get(URL, headers=headers)).json()] == ["c", "b", "a"]
    page = await client.get(URL, headers=headers, params={"limit": 2})
    assert [w["id"] for w in page.json()] == ["c", "b"]
    older = await client.get(URL, headers=headers, params={"before": "2026-11-21T06:00:00Z"})
    assert [w["id"] for w in older.json()] == ["a"]
    assert (await client.get(URL, headers=headers, params={"limit": 0})).status_code == 422


async def test_workouts_are_scoped_to_user(client: AsyncClient) -> None:
    """Rủi ro R04: người dùng khác không đọc, sửa hay xóa được buổi tập của mình."""
    owner = await auth_headers(client, "owner@example.com")
    other = await auth_headers(client, "other@example.com")
    await client.put(f"{URL}/run-1", headers=owner, json=workout())

    assert (await client.get(f"{URL}/run-1", headers=other)).status_code == 404
    assert (await client.delete(f"{URL}/run-1", headers=other)).status_code == 404
    assert (await client.get(URL, headers=other)).json() == []

    # Cùng id của người khác chỉ tạo bản riêng, không ghi đè bản của chủ.
    mine = await client.put(f"{URL}/run-1", headers=other, json=workout(title="Của tôi"))
    assert mine.status_code == 201
    assert (await client.get(f"{URL}/run-1", headers=owner)).json()["title"] == "Chạy ven sông Hàn"
    assert (await client.get(f"{URL}/run-1", headers=other)).json()["title"] == "Của tôi"


async def test_delete_then_not_found(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    await client.put(f"{URL}/run-1", headers=headers, json=workout())
    assert (await client.delete(f"{URL}/run-1", headers=headers)).status_code == 204
    assert (await client.get(f"{URL}/run-1", headers=headers)).status_code == 404
    assert (await client.delete(f"{URL}/run-1", headers=headers)).status_code == 404


@pytest.mark.parametrize(
    ("path_id", "change"),
    [
        ("run-1", {"id": "khac"}),  # id đường dẫn và body lệch nhau
        ("run-1", {"sport": "swim"}),
        ("run-1", {"v": 2}),
        ("run-1", {"endedAt": "2026-11-21T22:00:00Z"}),  # kết thúc trước bắt đầu
        ("run-1", {"distanceM": -1}),
        ("run-1", {"title": ""}),
        ("run-1", {"points": [{"lat": 100, "lon": 0, "t": "2026-11-21T22:30:00Z"}]}),
        ("bad id", {"id": "bad id"}),  # id chứa ký tự không cho phép
    ],
)
async def test_invalid_payload_is_rejected(client: AsyncClient, path_id: str, change: dict) -> None:
    headers = await auth_headers(client)
    res = await client.put(f"{URL}/{path_id}", headers=headers, json=workout(**change))
    assert res.status_code == 422
    assert (await client.get(URL, headers=headers)).json() == []


async def test_points_are_optional(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    body = workout()
    del body["points"]
    assert (await client.put(f"{URL}/run-1", headers=headers, json=body)).status_code == 201
    assert (await client.get(f"{URL}/run-1", headers=headers)).json()["points"] is None


@pytest.mark.parametrize("name", sorted(p.name for p in FIXTURES.glob("*.json")))
async def test_mobile_fixtures_round_trip(client: AsyncClient, name: str) -> None:
    """Dữ liệu mẫu của app (docs/14) lưu và đọc lại đúng, không mất điểm GPS."""
    headers = await auth_headers(client)
    sample = json.loads((FIXTURES / name).read_text(encoding="utf-8"))
    res = await client.put(f"{URL}/{sample['id']}", headers=headers, json=sample)
    assert res.status_code == 201, res.text

    got = (await client.get(f"{URL}/{sample['id']}", headers=headers)).json()
    for key in ("id", "sport", "title", "distanceM", "movingSeconds", "kcal", "polyline"):
        assert got[key] == sample[key]
    assert len(got["points"]) == len(sample["points"])
    assert [s["index"] for s in got["splits"]] == [s["index"] for s in sample["splits"]]
