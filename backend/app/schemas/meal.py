from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

MealType = Literal["breakfast", "lunch", "dinner", "snack"]


class MealCreate(BaseModel):
    meal_type: MealType
    name: str = Field(min_length=1)
    calories: int = Field(ge=0)
    logged_at: datetime | None = None


class MealUpdate(BaseModel):
    meal_type: MealType | None = None
    name: str | None = Field(default=None, min_length=1)
    calories: int | None = Field(default=None, ge=0)
    logged_at: datetime | None = None


class MealRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    meal_type: MealType
    name: str
    calories: int
    logged_at: datetime
    created_at: datetime


class MealDailyCalories(BaseModel):
    date: date
    total_calories: int
