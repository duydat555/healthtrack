import json
import math
import xml.etree.ElementTree as ET
from datetime import UTC, datetime, timedelta
from pathlib import Path

from httpx import AsyncClient

from app.services.workout_stats import (
    best_time_from_points,
    best_time_from_splits,
    decode_polyline,
    haversine_m,
)
from tests.helpers import auth_headers

URL = "/api/v1/workouts"
FIXTURES = Path(__file__).resolve().parents[2] / "mobile" / "test" / "fixtures" / "workouts"
GPX = "{http://www.topografix.com/GPX/1/1}"
M_PER_DEG_LAT = math.radians(1) * 6_371_000


def straight_track(speeds_mps: list[float], step_m: float = 10.0, seg: int = 0) -> list[dict]:
    """Đường thẳng theo hướng bắc, mỗi điểm cách nhau step_m; tốc độ đổi theo từng km."""
    start = datetime(2026, 11, 23, 6, 0, tzinfo=UTC)
    points, lat, elapsed = [], 16.0, 0.0
    points.append({"lat": lat, "lon": 108.0, "t": start.isoformat(), "seg": seg})
    for speed in speeds_mps:
        for _ in range(int(1000 / step_m)):
            lat += step_m / M_PER_DEG_LAT
            elapsed += step_m / speed
            t = (start + timedelta(seconds=elapsed)).isoformat()
            points.append({"lat": lat, "lon": 108.0, "t": t, "seg": seg})
    return points


def workout(wid: str, sport: str = "run", started: str = "2026-11-23T06:00:00Z", **extra) -> dict:
    body = {
        "v": 1,
        "id": wid,
        "sport": sport,
        "title": "Buổi tập",
        "startedAt": started,
        "endedAt": "2026-11-23T08:00:00Z",
        "movingSeconds": 1800.0,
        "distanceM": 6000.0,
        "elevationGainM": 10.0,
        "avgPaceSecPerKm": 300.0,
        "kcal": 300.0,
        "splits": [],
        "polyline": "",
    }
    body.update(extra)
    return body


# ---------------------------------------------------------------- phép tính thuần


def test_best_time_from_points_finds_fastest_window() -> None:
    # km 1: 4 m/s (250 s), km 2: 5 m/s (200 s), km 3: 4 m/s (250 s)
    points = straight_track([4, 5, 4])
    assert abs(best_time_from_points(points, 1000) - 200) < 1.0
    # 2 km nhanh nhất gồm km 2 và km 3 (hoặc km 1 và km 2): 450 s
    assert abs(best_time_from_points(points, 2000) - 450) < 1.0
    assert best_time_from_points(points, 5000) is None  # chưa đủ 5 km


def test_best_time_from_points_ignores_gap_between_segments() -> None:
    first = straight_track([4], seg=0)
    second = straight_track([4], seg=1)
    shifted = [
        {**p, "t": (datetime.fromisoformat(p["t"]) + timedelta(hours=1)).isoformat()}
        for p in second
    ]
    # Hai đoạn nằm cách nhau; quãng nghỉ và quãng nhảy giữa hai đoạn không được tính.
    assert abs(best_time_from_points(first + shifted, 1000) - 250) < 1.0
    # 1,9 km nối liền hai đoạn: vẫn là 475 s ở 4 m/s, không cộng giờ nghỉ.
    assert abs(best_time_from_points(first + shifted, 1900) - 475) < 1.0


def test_best_time_from_splits_uses_only_full_kilometres() -> None:
    splits = [
        {"index": 1, "distanceM": 1000, "seconds": 300},
        {"index": 2, "distanceM": 1000, "seconds": 280},
        {"index": 3, "distanceM": 1000, "seconds": 290},
        {"index": 4, "distanceM": 120, "seconds": 10},  # phần lẻ không tính
    ]
    assert best_time_from_splits(splits, 1) == 280
    assert best_time_from_splits(splits, 2) == 570
    assert best_time_from_splits(splits, 4) is None


def test_haversine_one_degree_of_latitude() -> None:
    assert abs(haversine_m(16, 108, 17, 108) - 111_195) < 50


def test_decode_polyline_matches_google_example() -> None:
    coords = decode_polyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
    assert coords == [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)]


# ---------------------------------------------------------------- /workouts/stats


async def test_stats_require_authentication(client: AsyncClient) -> None:
    assert (await client.get(f"{URL}/stats")).status_code == 401
    assert (await client.get(f"{URL}/run-1/gpx")).status_code == 401


async def test_stats_empty_account(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    res = await client.get(f"{URL}/stats", headers=headers, params={"date": "2026-11-23"})
    assert res.status_code == 200
    body = res.json()
    assert body["weekStart"] == "2026-11-23"  # thứ Hai
    assert body["monthStart"] == "2026-11-01"
    assert body["week"]["run"] == {
        "count": 0,
        "distanceM": 0,
        "movingSeconds": 0,
        "elevationGainM": 0,
        "kcal": 0,
    }
    assert body["records"]["run"] == {
        "fastest1k": None,
        "fastest5k": None,
        "fastest10k": None,
        "longest": None,
    }


async def test_stats_week_and_month_totals_by_sport(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    data = [
        ("a", "run", "2026-11-23T06:00:00Z", 5000),  # thứ Hai, tuần đang xem
        ("b", "run", "2026-11-26T06:00:00Z", 3000),  # thứ Năm, tuần đang xem
        ("c", "run", "2026-11-16T06:00:00Z", 8000),  # tuần trước, cùng tháng
        ("d", "run", "2026-10-30T06:00:00Z", 9000),  # tháng trước
        ("e", "ride", "2026-11-24T06:00:00Z", 20000),
    ]
    for wid, sport, started, dist in data:
        res = await client.put(
            f"{URL}/{wid}",
            headers=headers,
            json=workout(wid, sport, started, endedAt="2026-12-01T00:00:00Z", distanceM=dist),
        )
        assert res.status_code == 201

    body = (await client.get(f"{URL}/stats", headers=headers, params={"date": "2026-11-25"})).json()
    assert body["week"]["run"]["count"] == 2
    assert body["week"]["run"]["distanceM"] == 8000
    assert body["week"]["run"]["movingSeconds"] == 3600
    assert body["week"]["ride"]["distanceM"] == 20000
    assert body["week"]["walk"]["count"] == 0
    assert body["month"]["run"]["count"] == 3
    assert body["month"]["run"]["distanceM"] == 16000
    assert body["records"]["run"]["longest"]["workoutId"] == "d"  # lịch sử, không chỉ trong kỳ
    assert body["records"]["ride"]["longest"]["distanceM"] == 20000


async def test_stats_use_user_timezone_for_week_boundary(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    # 20:00 UTC Chủ nhật 22/11 là 03:00 thứ Hai 23/11 ở Việt Nam (UTC+7).
    await client.put(
        f"{URL}/a",
        headers=headers,
        json=workout("a", started="2026-11-22T20:00:00Z", endedAt="2026-11-22T21:00:00Z"),
    )
    utc = (await client.get(f"{URL}/stats", headers=headers, params={"date": "2026-11-23"})).json()
    vn = (
        await client.get(
            f"{URL}/stats", headers=headers, params={"date": "2026-11-23", "tz_offset": 420}
        )
    ).json()
    assert utc["week"]["run"]["count"] == 0
    assert vn["week"]["run"]["count"] == 1
    assert (
        await client.get(f"{URL}/stats", headers=headers, params={"tz_offset": 900})
    ).status_code == 422


async def test_stats_records_from_points_and_splits(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    # Có điểm GPS: 6 km, km 3 nhanh nhất (5 m/s = 200 s).
    points = straight_track([4, 4, 5, 4, 4, 4])
    await client.put(
        f"{URL}/gps",
        headers=headers,
        json=workout("gps", distanceM=6000, points=points),
    )
    # Không có điểm GPS, chỉ có split: 5 km, km 2 chậm hơn.
    splits = [
        {"index": i + 1, "distanceM": 1000, "seconds": s}
        for i, s in enumerate([300, 320, 290, 295, 310])
    ]
    await client.put(
        f"{URL}/split",
        headers=headers,
        json=workout("split", distanceM=5000, splits=splits),
    )
    rec = (await client.get(f"{URL}/stats", headers=headers)).json()["records"]["run"]
    assert abs(rec["fastest1k"]["seconds"] - 200) < 1.0
    assert rec["fastest1k"]["workoutId"] == "gps"
    assert rec["fastest5k"]["workoutId"] == "gps"  # 5 km tốt nhất: bỏ 1 km chậm ở hai đầu = 1200 s
    assert abs(rec["fastest5k"]["seconds"] - 1200) < 2.0
    assert rec["fastest10k"] is None  # không buổi nào đủ 10 km
    assert rec["longest"]["workoutId"] == "gps"


async def test_stats_are_scoped_to_user(client: AsyncClient) -> None:
    owner = await auth_headers(client, "owner@example.com")
    other = await auth_headers(client, "other@example.com")
    await client.put(f"{URL}/a", headers=owner, json=workout("a", distanceM=7000))
    body = (await client.get(f"{URL}/stats", headers=other)).json()
    assert body["records"]["run"]["longest"] is None
    assert all(t["count"] == 0 for t in body["month"].values())


async def test_stats_with_mobile_fixtures(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    for path in sorted(FIXTURES.glob("*.json")):
        sample = json.loads(path.read_text(encoding="utf-8"))
        await client.put(f"{URL}/{sample['id']}", headers=headers, json=sample)
    records = (await client.get(f"{URL}/stats", headers=headers)).json()["records"]
    run, ride, walk = records["run"], records["ride"], records["walk"]
    assert run["fastest1k"]["seconds"] < 400
    assert run["fastest5k"]["seconds"] < 1800
    assert run["fastest10k"] is None  # chạy 5,19 km
    assert ride["fastest10k"] is not None  # đạp xe 10,06 km
    assert walk["fastest1k"] is not None and walk["fastest5k"] is None


# ---------------------------------------------------------------- /workouts/{id}/gpx


async def test_gpx_export_from_points(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    points = straight_track([4], step_m=100)[:5]
    points[3]["seg"] = points[4]["seg"] = 1
    points[0]["alt"] = 8.1
    await client.put(
        f"{URL}/g1", headers=headers, json=workout("g1", title="Chạy <sáng> & vui", points=points)
    )
    res = await client.get(f"{URL}/g1/gpx", headers=headers)
    assert res.status_code == 200
    assert res.headers["content-type"].startswith("application/gpx+xml")
    assert 'filename="g1.gpx"' in res.headers["content-disposition"]

    root = ET.fromstring(res.content)  # XML hợp lệ, ký tự đặc biệt trong tên đã được escape
    assert root.get("version") == "1.1"
    assert root.find(f"{GPX}trk/{GPX}name").text == "Chạy <sáng> & vui"
    assert root.find(f"{GPX}trk/{GPX}type").text == "running"
    segs = root.findall(f"{GPX}trk/{GPX}trkseg")
    assert [len(s.findall(f"{GPX}trkpt")) for s in segs] == [3, 2]
    first = segs[0].find(f"{GPX}trkpt")
    assert first.get("lat") == "16.000000" and first.get("lon") == "108.000000"
    assert first.find(f"{GPX}ele").text == "8.1"
    assert first.find(f"{GPX}time").text.endswith("Z")


async def test_gpx_export_falls_back_to_polyline(client: AsyncClient) -> None:
    headers = await auth_headers(client)
    await client.put(
        f"{URL}/g2",
        headers=headers,
        json=workout("g2", sport="ride", polyline="_p~iF~ps|U_ulLnnqC_mqNvxq`@"),
    )
    res = await client.get(f"{URL}/g2/gpx", headers=headers)
    root = ET.fromstring(res.content)
    assert root.find(f"{GPX}trk/{GPX}type").text == "cycling"
    pts = root.findall(f"{GPX}trk/{GPX}trkseg/{GPX}trkpt")
    assert [(p.get("lat"), p.get("lon")) for p in pts][0] == ("38.500000", "-120.200000")
    assert len(pts) == 3


async def test_gpx_export_errors(client: AsyncClient) -> None:
    owner = await auth_headers(client, "owner@example.com")
    other = await auth_headers(client, "other@example.com")
    await client.put(f"{URL}/empty", headers=owner, json=workout("empty"))
    assert (await client.get(f"{URL}/empty/gpx", headers=owner)).status_code == 409
    assert (await client.get(f"{URL}/missing/gpx", headers=owner)).status_code == 404
    assert (await client.get(f"{URL}/empty/gpx", headers=other)).status_code == 404
