from datetime import date, datetime

from pydantic import BaseModel


class WeightToday(BaseModel):
    latest_kg: float
    bmi: float | None
    logged_at: datetime


class MedicationToday(BaseModel):
    taken: int  # số lần đã uống trong ngày
    missed: int  # số lần ghi nhận bỏ lỡ


class GoalProgress(BaseModel):
    goal_id: int
    metric: str
    period: str
    unit: str
    target_value: float
    current_value: float
    # Phần trăm hoàn thành (không giới hạn 100). null với cân nặng vì không xác định
    # được hướng tăng hay giảm; dùng current_value so với target_value.
    percent: float | None
    achieved: bool | None


class StatsSummary(BaseModel):
    date: date
    weight: WeightToday | None
    water_ml: int
    sleep_minutes: int
    medications: MedicationToday
    goals: list[GoalProgress]


class TrendPoint(BaseModel):
    date: date
    value: float | None  # null = ngày không có dữ liệu


class StatsTrend(BaseModel):
    metric: str
    unit: str
    range: str
    from_date: date
    to_date: date
    points: list[TrendPoint]
