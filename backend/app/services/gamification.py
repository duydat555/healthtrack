"""Health Score, streak, huy hiệu và thử thách tuần.

Health Score của một ngày là trung bình mức hoàn thành (tối đa 100%) của nước, giấc ngủ
và bước chân so với mục tiêu ngày đang hoạt động (không có thì dùng mức mặc định).
Một ngày "đạt" khi điểm từ ``PASS_SCORE``. Streak là số ngày đạt liên tiếp tính tới hôm nay
(hôm nay chưa đạt thì tính tới hôm qua để streak không về 0 giữa ngày).
"""

from dataclasses import dataclass
from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.achievement import Achievement
from app.models.goal import Goal
from app.models.step_log import StepLog
from app.schemas.gamification import (
    AchievementOut,
    GamificationSummary,
    ScoreComponent,
    WeeklyChallenge,
)
from app.services.stats import daily_values, local_today

PASS_SCORE = 70
WINDOW_DAYS = 60
DEFAULT_TARGETS = {"water": 2000.0, "sleep": 480.0, "steps": 8000.0}
CHALLENGE_TARGET = 5

# mã -> (tên, mô tả)
ACHIEVEMENTS: dict[str, tuple[str, str]] = {
    "first_log": ("Bước đầu tiên", "Ghi chỉ số sức khỏe đầu tiên"),
    "streak_3": ("Ba ngày liền", "Đạt từ 70 điểm 3 ngày liên tiếp"),
    "streak_7": ("Một tuần bền bỉ", "Đạt từ 70 điểm 7 ngày liên tiếp"),
    "streak_30": ("Thói quen vàng", "Đạt từ 70 điểm 30 ngày liên tiếp"),
    "water_goal": ("Đủ nước", "Uống đủ mục tiêu nước trong một ngày"),
    "sleep_goal": ("Ngủ đủ giấc", "Ngủ đủ mục tiêu trong một đêm"),
    "steps_10k": ("Mười nghìn bước", "Đi từ 10.000 bước trong một ngày"),
    "perfect_day": ("Ngày trọn vẹn", "Đạt 100 điểm trong một ngày"),
}


@dataclass
class DayData:
    water: float = 0
    sleep: float = 0
    steps: float = 0


def _percent(value: float, target: float) -> float:
    return min(value / target, 1.0) * 100 if target > 0 else 0.0


def day_score(data: DayData, targets: dict[str, float]) -> int:
    parts = [_percent(getattr(data, m), targets[m]) for m in DEFAULT_TARGETS]
    return round(sum(parts) / len(parts))


async def _targets(db: AsyncSession, user_id: int) -> dict[str, float]:
    goals = (
        await db.execute(
            select(Goal).where(Goal.user_id == user_id, Goal.is_active, Goal.period == "daily")
        )
    ).scalars()
    targets = dict(DEFAULT_TARGETS)
    for g in goals:
        if g.metric in targets:
            targets[g.metric] = g.target_value
    return targets


async def _days(
    db: AsyncSession, user_id: int, start: date, end: date, tz_offset: int
) -> dict[date, DayData]:
    water = await daily_values(db, user_id, "water", start, end, tz_offset)
    sleep = await daily_values(db, user_id, "sleep", start, end, tz_offset)
    steps = {
        row.day: float(row.steps)
        for row in (
            await db.execute(
                select(StepLog).where(
                    StepLog.user_id == user_id, StepLog.day >= start, StepLog.day <= end
                )
            )
        ).scalars()
    }
    return {
        start + timedelta(days=i): DayData(
            water.get(d := start + timedelta(days=i), 0),
            sleep.get(d, 0),
            steps.get(d, 0),
        )
        for i in range((end - start).days + 1)
    }


def _streaks(scores: dict[date, int], today: date) -> tuple[int, int]:
    """(streak hiện tại, streak dài nhất) trong cửa sổ."""
    best = run = 0
    for d in sorted(scores):
        run = run + 1 if scores[d] >= PASS_SCORE else 0
        best = max(best, run)
    cursor = today if scores.get(today, 0) >= PASS_SCORE else today - timedelta(days=1)
    current = 0
    while scores.get(cursor, 0) >= PASS_SCORE:
        current += 1
        cursor -= timedelta(days=1)
    return current, best


def _earned(days: dict[date, DayData], targets: dict[str, float], best_streak: int) -> set[str]:
    codes: set[str] = set()
    if any(d.water or d.sleep or d.steps for d in days.values()):
        codes.add("first_log")
    for n in (3, 7, 30):
        if best_streak >= n:
            codes.add(f"streak_{n}")
    if any(d.water >= targets["water"] for d in days.values()):
        codes.add("water_goal")
    if any(d.sleep >= targets["sleep"] for d in days.values()):
        codes.add("sleep_goal")
    if any(d.steps >= 10_000 for d in days.values()):
        codes.add("steps_10k")
    if any(day_score(d, targets) == 100 for d in days.values()):
        codes.add("perfect_day")
    return codes


async def _award(db: AsyncSession, user_id: int, earned: set[str]) -> list[str]:
    have = set(
        (await db.execute(select(Achievement.code).where(Achievement.user_id == user_id)))
        .scalars()
        .all()
    )
    new = sorted(earned - have)
    for code in new:
        db.add(Achievement(user_id=user_id, code=code))
    if new:
        try:
            await db.commit()
        except IntegrityError:  # hai yêu cầu song song cùng trao một huy hiệu
            await db.rollback()
            return []
    return new


async def build_summary(db: AsyncSession, user_id: int, tz_offset: int = 0) -> GamificationSummary:
    today = local_today(tz_offset)
    start = today - timedelta(days=WINDOW_DAYS - 1)
    targets = await _targets(db, user_id)
    days = await _days(db, user_id, start, today, tz_offset)
    scores = {d: day_score(v, targets) for d, v in days.items()}
    streak, best = _streaks(scores, today)
    new = await _award(db, user_id, _earned(days, targets, best))

    week = [today - timedelta(days=i) for i in range(7)]
    done = sum(1 for d in week if days[d].water >= targets["water"])
    now = days[today]
    return GamificationSummary(
        score=scores[today],
        components=[
            ScoreComponent(metric=m, percent=round(_percent(getattr(now, m), targets[m]), 1))
            for m in DEFAULT_TARGETS
        ],
        streak=streak,
        best_streak=best,
        challenge=WeeklyChallenge(
            code="water_week",
            title=f"Uống đủ nước {CHALLENGE_TARGET} ngày trong tuần",
            progress=min(done, CHALLENGE_TARGET),
            target=CHALLENGE_TARGET,
        ),
        new_achievements=new,
    )


async def list_achievements(
    db: AsyncSession, user_id: int, tz_offset: int = 0
) -> list[AchievementOut]:
    await build_summary(db, user_id, tz_offset)  # trao huy hiệu còn thiếu trước khi liệt kê
    rows = {
        a.code: a.earned_at
        for a in (
            await db.execute(select(Achievement).where(Achievement.user_id == user_id))
        ).scalars()
    }
    return [
        AchievementOut(code=c, title=t, description=d, earned_at=rows.get(c))
        for c, (t, d) in ACHIEVEMENTS.items()
    ]
