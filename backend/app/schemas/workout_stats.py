"""Schema thống kê hoạt động ngoài trời. JSON camelCase giống /workouts."""

from datetime import date, datetime

from pydantic import Field

from app.schemas.workout import CamelModel


class SportTotals(CamelModel):
    count: int = 0
    distance_m: float = 0
    moving_seconds: float = 0
    elevation_gain_m: float = 0
    kcal: float = 0


class TimeRecord(CamelModel):
    """Thời gian nhanh nhất cho một mốc quãng đường."""

    seconds: float
    workout_id: str
    started_at: datetime


class DistanceRecord(CamelModel):
    """Buổi tập có quãng đường dài nhất."""

    distance_m: float
    workout_id: str
    started_at: datetime


class SportRecords(CamelModel):
    fastest_1k: TimeRecord | None = Field(default=None, alias="fastest1k")
    fastest_5k: TimeRecord | None = Field(default=None, alias="fastest5k")
    fastest_10k: TimeRecord | None = Field(default=None, alias="fastest10k")
    longest: DistanceRecord | None = None


class WorkoutStats(CamelModel):
    date: date
    week_start: date  # thứ Hai của tuần chứa `date`, theo múi giờ người dùng
    month_start: date
    week: dict[str, SportTotals]
    month: dict[str, SportTotals]
    records: dict[str, SportRecords]
