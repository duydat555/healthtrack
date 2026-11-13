from datetime import date, datetime

from pydantic import BaseModel, Field, model_validator


class SyncSteps(BaseModel):
    day: date
    steps: int = Field(ge=0, le=200_000)


class SyncSleep(BaseModel):
    external_id: str = Field(min_length=1, max_length=64)
    start_at: datetime
    end_at: datetime

    @model_validator(mode="after")
    def _end_after_start(self) -> "SyncSleep":
        if self.end_at <= self.start_at:
            raise ValueError("end_at phải sau start_at")
        return self


class SyncWeight(BaseModel):
    external_id: str = Field(min_length=1, max_length=64)
    weight_kg: float = Field(gt=0, le=500)
    logged_at: datetime


class HealthKitSync(BaseModel):
    steps: list[SyncSteps] = Field(default_factory=list, max_length=400)
    sleep: list[SyncSleep] = Field(default_factory=list, max_length=500)
    weights: list[SyncWeight] = Field(default_factory=list, max_length=500)


class SyncCount(BaseModel):
    created: int = 0
    updated: int = 0


class HealthKitSyncResult(BaseModel):
    steps: SyncCount
    sleep: SyncCount
    weights: SyncCount
