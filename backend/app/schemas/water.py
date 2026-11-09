from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class WaterCreate(BaseModel):
    amount_ml: int = Field(gt=0, le=5000)
    logged_at: datetime | None = None  # bỏ trống = thời điểm hiện tại


class WaterUpdate(BaseModel):
    amount_ml: int | None = Field(default=None, gt=0, le=5000)
    logged_at: datetime | None = None


class WaterRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    amount_ml: int
    logged_at: datetime


class WaterDailyTotal(BaseModel):
    date: date
    total_ml: int
