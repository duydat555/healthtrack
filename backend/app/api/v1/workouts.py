from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.workout import ID_PATTERN, WorkoutIn, WorkoutRead, WorkoutSummary
from app.services import workout as workout_service

router = APIRouter(prefix="/workouts", tags=["workouts"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
WorkoutId = Annotated[str, Path(pattern=ID_PATTERN)]
NOT_FOUND = "Không tìm thấy buổi tập"


@router.get("", response_model=list[WorkoutSummary])
async def list_workouts(
    user: CurrentUser,
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    before: Annotated[
        datetime | None, Query(description="Chỉ lấy buổi bắt đầu trước mốc này")
    ] = None,
) -> list[WorkoutSummary]:
    rows = await workout_service.list_workouts(db, user.id, limit=limit, before=before)
    return [workout_service.to_summary(row) for row in rows]


@router.get("/{workout_id}", response_model=WorkoutRead)
async def get_workout(workout_id: WorkoutId, user: CurrentUser, db: DbSession) -> WorkoutRead:
    row = await workout_service.get_workout(db, user.id, workout_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return workout_service.to_read(row)


@router.put("/{workout_id}", response_model=WorkoutRead)
async def put_workout(
    workout_id: WorkoutId,
    data: WorkoutIn,
    user: CurrentUser,
    db: DbSession,
    response: Response,
) -> WorkoutRead:
    if data.id != workout_id:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY, "id trong đường dẫn và body phải trùng nhau"
        )
    row, created = await workout_service.upsert_workout(db, user.id, data)
    response.status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
    return workout_service.to_read(row)


@router.delete("/{workout_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_workout(workout_id: WorkoutId, user: CurrentUser, db: DbSession) -> Response:
    if not await workout_service.delete_workout(db, user.id, workout_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
