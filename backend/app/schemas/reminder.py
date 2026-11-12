from datetime import datetime, time
from typing import Literal

from pydantic import BaseModel, ConfigDict, model_validator

ReminderKind = Literal["water", "medication", "sleep"]


class ReminderCreate(BaseModel):
    kind: ReminderKind
    at_time: time
    enabled: bool = True


class ReminderUpdate(BaseModel):
    kind: ReminderKind | None = None
    at_time: time | None = None
    enabled: bool | None = None

    @model_validator(mode="after")
    def has_changes(self) -> "ReminderUpdate":
        if not self.model_fields_set:
            raise ValueError("Cần cung cấp ít nhất một trường để cập nhật")
        if any(getattr(self, field) is None for field in self.model_fields_set):
            raise ValueError("Trường cập nhật không được là null")
        return self


class ReminderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    kind: ReminderKind
    at_time: time
    enabled: bool
    created_at: datetime
