from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, computed_field, model_validator

Metric = Literal["weight", "water", "sleep", "steps", "calories"]
Period = Literal["daily", "weekly"]

# Đơn vị và giá trị mục tiêu tối đa hợp lý của từng chỉ số
METRIC_UNITS: dict[str, str] = {
    "weight": "kg",
    "water": "ml",
    "sleep": "minutes",
    "steps": "steps",
    "calories": "kcal",
}
METRIC_MAX: dict[str, float] = {
    "weight": 500,
    "water": 20000,
    "sleep": 1440,
    "steps": 200000,
    "calories": 20000,
}


def check_target(metric: str, value: float) -> None:
    if value > METRIC_MAX[metric]:
        raise ValueError(f"target_value của {metric} tối đa {METRIC_MAX[metric]:g}")


class GoalCreate(BaseModel):
    metric: Metric
    period: Period = "daily"
    target_value: float = Field(gt=0)

    @model_validator(mode="after")
    def _within_range(self) -> "GoalCreate":
        check_target(self.metric, self.target_value)
        return self


class GoalUpdate(BaseModel):
    """Không cho đổi `metric`; muốn đổi chỉ số thì tạo mục tiêu mới."""

    period: Period | None = None
    target_value: float | None = Field(default=None, gt=0)
    is_active: bool | None = None


class GoalRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    metric: Metric
    period: Period
    target_value: float
    is_active: bool
    created_at: datetime

    @computed_field  # type: ignore[prop-decorator]
    @property
    def unit(self) -> str:
        return METRIC_UNITS[self.metric]
