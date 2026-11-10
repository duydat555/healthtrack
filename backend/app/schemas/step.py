from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class StepCreate(BaseModel):
    steps: int = Field(ge=0)
    day: date


class StepUpdate(BaseModel):
    steps: int | None = Field(default=None, ge=0)
    day: date | None = None


class StepRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    steps: int
    day: date
    created_at: datetime
