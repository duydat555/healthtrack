"""Thống kê tổng hợp. Ngày được tính theo UTC.

Quy ước "giá trị theo ngày" của từng chỉ số:
- water: tổng ml theo ngày ghi (``logged_at``)
- sleep: tổng phút của các giấc ngủ kết thúc (``end_at``) trong ngày; mục tiêu tuần so với
  trung bình mỗi đêm
- weight: cân nặng ghi cuối cùng trong ngày
- steps, calories: chưa có bảng dữ liệu nên chưa có giá trị
"""

from collections import defaultdict
from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.goal import Goal
from app.models.medication import Medication, MedicationLog
from app.models.sleep_log import SleepLog
from app.models.water_log import WaterLog
from app.models.weight_log import WeightLog
from app.schemas.goal import METRIC_UNITS
from app.schemas.sleep import as_utc
from app.schemas.stats import (
    GoalProgress,
    MedicationToday,
    StatsSummary,
    StatsTrend,
    TrendPoint,
    WeightToday,
)

WEEK_DAYS = 7


def day_start(day: date) -> datetime:
    return datetime.combine(day, time.min, tzinfo=UTC)


def _day_of(value: datetime) -> date:
    return as_utc(value).date()


async def daily_values(
    db: AsyncSession, user_id: int, metric: str, start: date, end: date
) -> dict[date, float]:
    """Giá trị của ``metric`` theo từng ngày trong [start, end]; ngày không có dữ liệu bị bỏ qua."""
    lo, hi = day_start(start), day_start(end + timedelta(days=1))
    totals: dict[date, float] = defaultdict(float)
    if metric == "water":
        stmt = select(WaterLog.logged_at, WaterLog.amount_ml).where(
            WaterLog.user_id == user_id, WaterLog.logged_at >= lo, WaterLog.logged_at < hi
        )
        for logged_at, amount in (await db.execute(stmt)).all():
            totals[_day_of(logged_at)] += amount
    elif metric == "sleep":
        stmt = select(SleepLog.start_at, SleepLog.end_at).where(
            SleepLog.user_id == user_id, SleepLog.end_at >= lo, SleepLog.end_at < hi
        )
        for start_at, end_at in (await db.execute(stmt)).all():
            minutes = (as_utc(end_at) - as_utc(start_at)).total_seconds() // 60
            totals[_day_of(end_at)] += minutes
    elif metric == "weight":
        stmt = (
            select(WeightLog.logged_at, WeightLog.weight_kg)
            .where(
                WeightLog.user_id == user_id, WeightLog.logged_at >= lo, WeightLog.logged_at < hi
            )
            .order_by(WeightLog.logged_at)
        )
        for logged_at, kg in (await db.execute(stmt)).all():
            totals[_day_of(logged_at)] = kg  # bản ghi sau ghi đè bản ghi trước
    return dict(totals)


def _progress(goal: Goal, values: dict[date, float], today: date) -> GoalProgress:
    window = 1 if goal.period == "daily" else WEEK_DAYS
    days = [today - timedelta(days=i) for i in range(window)]
    in_window = [(d, values[d]) for d in days if d in values]
    if goal.metric == "weight":
        current = max(in_window)[1] if in_window else 0.0  # ngày gần nhất có dữ liệu
        percent, achieved = None, None
    else:
        total = sum(v for _, v in in_window)
        # Mục tiêu ngủ là số phút mỗi đêm (tối đa 1440) nên so với trung bình các đêm có dữ liệu
        current = total / len(in_window) if goal.metric == "sleep" and in_window else total
        percent = round(current / goal.target_value * 100, 1)
        achieved = current >= goal.target_value
    return GoalProgress(
        goal_id=goal.id,
        metric=goal.metric,
        period=goal.period,
        unit=METRIC_UNITS[goal.metric],
        target_value=goal.target_value,
        current_value=round(current, 1),
        percent=percent,
        achieved=achieved,
    )


async def build_summary(db: AsyncSession, user_id: int, today: date) -> StatsSummary:
    lo, hi = day_start(today), day_start(today + timedelta(days=1))

    latest = (
        await db.execute(
            select(WeightLog)
            .where(
                WeightLog.user_id == user_id, WeightLog.logged_at >= lo, WeightLog.logged_at < hi
            )
            .order_by(WeightLog.logged_at.desc(), WeightLog.id.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    weight = (
        WeightToday(latest_kg=latest.weight_kg, bmi=latest.bmi, logged_at=latest.logged_at)
        if latest
        else None
    )

    med_rows = (
        await db.execute(
            select(MedicationLog.taken)
            .join(Medication, Medication.id == MedicationLog.medication_id)
            .where(
                Medication.user_id == user_id,
                MedicationLog.taken_at >= lo,
                MedicationLog.taken_at < hi,
            )
        )
    ).scalars()
    flags = list(med_rows)
    medications = MedicationToday(taken=sum(flags), missed=len(flags) - sum(flags))

    goals = list(
        (
            await db.execute(
                select(Goal).where(Goal.user_id == user_id, Goal.is_active).order_by(Goal.id)
            )
        ).scalars()
    )
    start = today - timedelta(days=WEEK_DAYS - 1)
    cache: dict[str, dict[date, float]] = {}
    for metric in {g.metric for g in goals} | {"water", "sleep"}:
        cache[metric] = await daily_values(db, user_id, metric, start, today)

    return StatsSummary(
        date=today,
        weight=weight,
        water_ml=int(cache["water"].get(today, 0)),
        sleep_minutes=int(cache["sleep"].get(today, 0)),
        medications=medications,
        goals=[_progress(g, cache[g.metric], today) for g in goals],
    )


TREND_RANGES = {"7d": 7, "30d": 30, "90d": 90}


async def build_trend(
    db: AsyncSession, user_id: int, metric: str, range_: str, end: date
) -> StatsTrend:
    """Giá trị theo ngày của ``metric`` cho ``range_`` ngày kết thúc ở ``end``.

    Mỗi ngày có đúng một điểm; ngày không có dữ liệu có ``value`` là null để biểu đồ
    phân biệt được "không ghi" với "bằng 0".
    """
    days = TREND_RANGES[range_]
    start = end - timedelta(days=days - 1)
    values = await daily_values(db, user_id, metric, start, end)
    points = [
        TrendPoint(date=d, value=round(values[d], 1) if d in values else None)
        for d in (start + timedelta(days=i) for i in range(days))
    ]
    return StatsTrend(
        metric=metric,
        unit=METRIC_UNITS[metric],
        range=range_,
        from_date=start,
        to_date=end,
        points=points,
    )
