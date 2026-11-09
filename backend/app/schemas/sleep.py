from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict, Field, computed_field


def as_utc(value: datetime) -> datetime:
    """Gắn UTC cho datetime không có múi giờ để so sánh an toàn."""
    return value if value.tzinfo else value.replace(tzinfo=UTC)


class SleepCreate(BaseModel):
    start_at: datetime
    end_at: datetime
    quality: int | None = Field(default=None, ge=1, le=5)


class SleepUpdate(BaseModel):
    start_at: datetime | None = None
    end_at: datetime | None = None
    quality: int | None = Field(default=None, ge=1, le=5)


class SleepRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    start_at: datetime
    end_at: datetime
    quality: int | None

    @computed_field  # type: ignore[prop-decorator]
    @property
    def duration_minutes(self) -> int:
        return int((as_utc(self.end_at) - as_utc(self.start_at)).total_seconds() // 60)
