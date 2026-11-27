"""Schema buổi tập. JSON dùng camelCase đúng hợp đồng docs/14 (v, startedAt, distanceM...)."""

from datetime import UTC, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from pydantic.alias_generators import to_camel

Sport = Literal["run", "walk", "ride"]
ID_PATTERN = r"^[A-Za-z0-9_-]{1,64}$"
MAX_POINTS = 50_000
MAX_SPLITS = 2_000
MAX_POLYLINE = 400_000


def as_utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=UTC)


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, from_attributes=True)


class WorkoutPoint(CamelModel):
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    t: datetime
    alt: float | None = None
    speed: float | None = Field(default=None, ge=0)
    acc: float | None = Field(default=None, ge=0)
    seg: int = Field(default=0, ge=0)


class WorkoutSplit(CamelModel):
    index: int = Field(ge=1)
    distance_m: float = Field(ge=0)
    seconds: float = Field(ge=0)
    pace_sec_per_km: float | None = Field(default=None, ge=0)
    elevation_delta_m: float = 0


class WorkoutBase(CamelModel):
    v: int = 1
    id: str = Field(pattern=ID_PATTERN)
    sport: Sport
    title: str = Field(min_length=1, max_length=120)
    started_at: datetime
    ended_at: datetime
    moving_seconds: float = Field(ge=0)
    distance_m: float = Field(ge=0)
    elevation_gain_m: float = Field(default=0, ge=0)
    avg_pace_sec_per_km: float | None = Field(default=None, ge=0)
    kcal: float = Field(default=0, ge=0)
    splits: list[WorkoutSplit] = Field(default_factory=list, max_length=MAX_SPLITS)
    polyline: str = Field(default="", max_length=MAX_POLYLINE)


class WorkoutIn(WorkoutBase):
    points: list[WorkoutPoint] | None = Field(default=None, max_length=MAX_POINTS)

    @field_validator("v")
    @classmethod
    def _version(cls, value: int) -> int:
        if value != 1:
            raise ValueError("Chỉ hỗ trợ định dạng v = 1")
        return value

    @model_validator(mode="after")
    def _order(self) -> "WorkoutIn":
        if as_utc(self.ended_at) < as_utc(self.started_at):
            raise ValueError("endedAt phải sau hoặc bằng startedAt")
        return self


class WorkoutSummary(WorkoutBase):
    """Một buổi tập không kèm điểm GPS (dùng cho danh sách)."""

    @field_validator("started_at", "ended_at")
    @classmethod
    def _utc(cls, value: datetime) -> datetime:
        return as_utc(value)


class WorkoutRead(WorkoutSummary):
    points: list[WorkoutPoint] | None = None
