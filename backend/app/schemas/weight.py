from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class WeightCreate(BaseModel):
    weight_kg: float = Field(gt=0, le=500)
    logged_at: datetime | None = None  # bỏ trống = thời điểm hiện tại


class WeightUpdate(BaseModel):
    weight_kg: float | None = Field(default=None, gt=0, le=500)
    logged_at: datetime | None = None


class WeightRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    weight_kg: float
    bmi: float | None
    logged_at: datetime
