from datetime import date
from typing import Literal

from pydantic import BaseModel, Field


class CoachMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=4000)


class CoachChatRequest(BaseModel):
    messages: list[CoachMessage] = Field(min_length=1, max_length=30)
    tz_offset: int = Field(default=0, ge=-720, le=840)


class WeeklyInsight(BaseModel):
    week_start: date
    content: str
    model: str
