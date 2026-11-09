from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class MedicationCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    dosage: str | None = Field(default=None, max_length=100)
    schedule: str | None = Field(default=None, max_length=255)


class MedicationUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    dosage: str | None = Field(default=None, max_length=100)
    schedule: str | None = Field(default=None, max_length=255)
    is_active: bool | None = None


class MedicationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    dosage: str | None
    schedule: str | None
    is_active: bool


class MedicationLogCreate(BaseModel):
    taken_at: datetime | None = None  # bỏ trống = thời điểm hiện tại
    taken: bool = True  # False = ghi nhận đã bỏ lỡ liều


class MedicationLogRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    medication_id: int
    taken_at: datetime
    taken: bool
