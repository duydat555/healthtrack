from datetime import UTC, date, datetime, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.meal import MealCreate, MealDailyCalories, MealRead, MealUpdate
from app.services import meal as meal_service

router = APIRouter(prefix="/meals", tags=["meals"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
TzOffset = Annotated[int, Query(ge=-720, le=840)]
NOT_FOUND = "Không tìm thấy bản ghi bữa ăn"


@router.get("", response_model=list[MealRead])
async def list_meals(
    user: CurrentUser,
    db: DbSession,
    from_: Annotated[datetime | None, Query(alias="from")] = None,
    to: datetime | None = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[MealRead]:
    if from_ is not None and to is not None and from_ > to:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY, "'from' phải trước hoặc bằng 'to'"
        )
    rows = await meal_service.list_meals(
        db, user.id, from_, to, skip=offset, limit=limit
    )
    return [MealRead.model_validate(row) for row in rows]


@router.get("/total", response_model=MealDailyCalories)
async def daily_total(
    user: CurrentUser,
    db: DbSession,
    day: Annotated[date | None, Query(alias="date")] = None,
    tz_offset: TzOffset = 0,
) -> MealDailyCalories:
    day = day or (datetime.now(UTC) + timedelta(minutes=tz_offset)).date()
    total = await meal_service.daily_calories(db, user.id, day, tz_offset)
    return MealDailyCalories(date=day, total_calories=total)


@router.post("", response_model=MealRead, status_code=status.HTTP_201_CREATED)
async def create_meal(data: MealCreate, user: CurrentUser, db: DbSession) -> MealRead:
    return MealRead.model_validate(await meal_service.create_meal(db, user.id, data))


@router.patch("/{meal_id}", response_model=MealRead)
async def update_meal(
    meal_id: int, data: MealUpdate, user: CurrentUser, db: DbSession
) -> MealRead:
    row = await meal_service.update_meal(db, user.id, meal_id, data)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return MealRead.model_validate(row)


@router.delete("/{meal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_meal(meal_id: int, user: CurrentUser, db: DbSession) -> Response:
    if not await meal_service.delete_meal(db, user.id, meal_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
