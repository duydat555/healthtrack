"""Thống kê hoạt động ngoài trời, kỷ lục cá nhân và xuất GPX.

Quy ước:
- Tuần bắt đầu từ thứ Hai, ranh giới ngày/tuần/tháng tính theo múi giờ ``tz_offset`` (phút lệch
  so với UTC, VN là 420) giống ``/stats/*``.
- Tổng tuần và tháng tính theo thời điểm bắt đầu buổi tập.
- Kỷ lục tính trên toàn bộ lịch sử, tách theo môn. Thời gian nhanh nhất cho 1 km, 5 km, 10 km lấy
  từ điểm GPS (cửa sổ trượt, chỉ tính thời gian vận động, bỏ quãng giữa hai đoạn tạm dừng); nếu
  buổi tập không có điểm GPS thì ghép các split 1 km liên tiếp.
"""

import math
from datetime import UTC, date, datetime, timedelta
from xml.sax.saxutils import escape, quoteattr

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.workout import Workout
from app.schemas.workout import as_utc
from app.schemas.workout_stats import (
    DistanceRecord,
    SportRecords,
    SportTotals,
    TimeRecord,
    WorkoutStats,
)
from app.services.stats import day_start

SPORTS = ("run", "walk", "ride")
EARTH_RADIUS_M = 6_371_000
RECORD_TARGETS_M = {"fastest_1k": 1_000, "fastest_5k": 5_000, "fastest_10k": 10_000}
FULL_SPLIT_M = 999  # split đủ 1 km (cho phép sai số làm tròn)
GPX_TYPE = {"run": "running", "walk": "walking", "ride": "cycling"}


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_RADIUS_M * math.asin(math.sqrt(a))


def _parse_time(value: str) -> datetime:
    return as_utc(datetime.fromisoformat(value.replace("Z", "+00:00")))


def week_start_of(day: date) -> date:
    return day - timedelta(days=day.weekday())


def local_day(value: datetime, tz_offset: int) -> date:
    return (as_utc(value) + timedelta(minutes=tz_offset)).date()


# ---------------------------------------------------------------- Kỷ lục


def best_time_from_points(points: list[dict], target_m: float) -> float | None:
    """Thời gian vận động ngắn nhất (giây) để đi đủ ``target_m`` mét liên tục."""
    if len(points) < 2:
        return None
    cum_d, cum_t = [0.0], [0.0]
    prev = points[0]
    prev_t = _parse_time(prev["t"])
    for cur in points[1:]:
        cur_t = _parse_time(cur["t"])
        if cur.get("seg", 0) == prev.get("seg", 0):
            dist = haversine_m(prev["lat"], prev["lon"], cur["lat"], cur["lon"])
            dt = max((cur_t - prev_t).total_seconds(), 0.0)
        else:  # quãng giữa hai đoạn tạm dừng không tính
            dist, dt = 0.0, 0.0
        cum_d.append(cum_d[-1] + dist)
        cum_t.append(cum_t[-1] + dt)
        prev, prev_t = cur, cur_t

    if cum_d[-1] < target_m:
        return None
    best: float | None = None
    j = 1
    for i in range(len(points) - 1):
        j = max(j, i + 1)
        while j < len(points) and cum_d[j] - cum_d[i] < target_m:
            j += 1
        if j >= len(points):
            break
        span = cum_d[j] - cum_d[j - 1]
        need = target_m - (cum_d[j - 1] - cum_d[i])
        frac = need / span if span > 0 else 1.0
        end_t = cum_t[j - 1] + frac * (cum_t[j] - cum_t[j - 1])
        elapsed = end_t - cum_t[i]
        if best is None or elapsed < best:
            best = elapsed
    return best


def best_time_from_splits(splits: list[dict], km: int) -> float | None:
    """Ghép ``km`` split 1 km liên tiếp (chỉ các split đủ 1 km) và lấy tổng thời gian nhỏ nhất."""
    full = [s for s in sorted(splits, key=lambda s: s["index"]) if s["distanceM"] >= FULL_SPLIT_M]
    if len(full) < km:
        return None
    return min(sum(s["seconds"] for s in full[i : i + km]) for i in range(len(full) - km + 1))


def _best_for(row: Workout, key: str) -> float | None:
    target = RECORD_TARGETS_M[key]
    if row.distance_m < target * 0.999:
        return None
    if row.points:
        return best_time_from_points(row.points, target)
    return best_time_from_splits(row.splits or [], target // 1000)


# ---------------------------------------------------------------- Thống kê


async def build_stats(
    db: AsyncSession, user_id: int, day: date, tz_offset: int = 0
) -> WorkoutStats:
    week_start = week_start_of(day)
    month_start = day.replace(day=1)
    rows = list(
        (
            await db.execute(
                select(Workout)
                .where(Workout.user_id == user_id)
                .order_by(Workout.started_at, Workout.id)
            )
        )
        .scalars()
        .all()
    )

    week_lo, week_hi = (
        day_start(week_start, tz_offset),
        day_start(week_start + timedelta(days=7), tz_offset),
    )
    next_month = (month_start + timedelta(days=32)).replace(day=1)
    month_lo, month_hi = day_start(month_start, tz_offset), day_start(next_month, tz_offset)

    week = {s: SportTotals() for s in SPORTS}
    month = {s: SportTotals() for s in SPORTS}
    best: dict[str, dict[str, tuple[float, Workout]]] = {s: {} for s in SPORTS}
    longest: dict[str, Workout] = {}

    for row in rows:
        if row.sport not in week:
            continue
        started = as_utc(row.started_at)
        for totals, lo, hi in ((week, week_lo, week_hi), (month, month_lo, month_hi)):
            if lo <= started < hi:
                t = totals[row.sport]
                t.count += 1
                t.distance_m += row.distance_m
                t.moving_seconds += row.moving_seconds
                t.elevation_gain_m += row.elevation_gain_m
                t.kcal += row.kcal
        if row.sport not in longest or row.distance_m > longest[row.sport].distance_m:
            longest[row.sport] = row
        for key in RECORD_TARGETS_M:
            seconds = _best_for(row, key)
            if seconds is not None and (
                key not in best[row.sport] or seconds < best[row.sport][key][0]
            ):
                best[row.sport][key] = (seconds, row)

    records: dict[str, SportRecords] = {}
    for sport in SPORTS:
        rec = SportRecords()
        for key, (seconds, row) in best[sport].items():
            setattr(
                rec,
                key,
                TimeRecord(
                    seconds=round(seconds, 2),
                    workout_id=row.workout_id,
                    started_at=as_utc(row.started_at),
                ),
            )
        if sport in longest:
            row = longest[sport]
            rec.longest = DistanceRecord(
                distance_m=row.distance_m,
                workout_id=row.workout_id,
                started_at=as_utc(row.started_at),
            )
        records[sport] = rec

    return WorkoutStats(
        date=day,
        week_start=week_start,
        month_start=month_start,
        week=week,
        month=month,
        records=records,
    )


# ---------------------------------------------------------------- GPX


def decode_polyline(encoded: str) -> list[tuple[float, float]]:
    """Giải mã Google Encoded Polyline (độ chính xác 1e5) thành danh sách (lat, lon)."""
    coords: list[tuple[float, float]] = []
    index = lat = lon = 0
    while index < len(encoded):
        values = []
        for _ in range(2):
            shift = result = 0
            while True:
                byte = ord(encoded[index]) - 63
                index += 1
                result |= (byte & 0x1F) << shift
                shift += 5
                if byte < 0x20:
                    break
            values.append(~(result >> 1) if result & 1 else result >> 1)
        lat += values[0]
        lon += values[1]
        coords.append((lat / 1e5, lon / 1e5))
    return coords


class NoRouteError(Exception):
    """Buổi tập không có điểm GPS lẫn polyline nên không xuất GPX được."""


def build_gpx(row: Workout) -> str:
    started = as_utc(row.started_at).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<gpx version="1.1" creator="HealthTrack" xmlns="http://www.topografix.com/GPX/1/1">',
        f"  <metadata><name>{escape(row.title)}</name><time>{started}</time></metadata>",
        "  <trk>",
        f"    <name>{escape(row.title)}</name>",
        f"    <type>{GPX_TYPE.get(row.sport, 'other')}</type>",
    ]
    if row.points:
        segments: dict[int, list[dict]] = {}
        for p in row.points:
            segments.setdefault(int(p.get("seg", 0)), []).append(p)
        for seg in sorted(segments):
            lines.append("    <trkseg>")
            for p in segments[seg]:
                t = _parse_time(p["t"]).astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
                ele = f"<ele>{p['alt']:.1f}</ele>" if p.get("alt") is not None else ""
                lines.append(
                    f"      <trkpt lat={quoteattr(f'{p["lat"]:.6f}')} "
                    f"lon={quoteattr(f'{p["lon"]:.6f}')}>{ele}<time>{t}</time></trkpt>"
                )
            lines.append("    </trkseg>")
    elif row.polyline:
        lines.append("    <trkseg>")
        for lat, lon in decode_polyline(row.polyline):
            lines.append(f'      <trkpt lat="{lat:.6f}" lon="{lon:.6f}"/>')
        lines.append("    </trkseg>")
    else:
        raise NoRouteError
    lines += ["  </trk>", "</gpx>", ""]
    return "\n".join(lines)
