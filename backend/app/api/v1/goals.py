from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.goal import GoalCreate, GoalRead, GoalUpdate, Metric
from app.services import goal as goal_service

router = APIRouter(prefix="/goals", tags=["goals"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
NOT_FOUND = "Không tìm thấy mục tiêu"
CONFLICT = "Chỉ số này đã có mục tiêu đang hoạt động, hãy tắt hoặc sửa mục tiêu đó"


@router.get("", response_model=list[GoalRead])
async def list_goals(
    user: CurrentUser,
    db: DbSession,
    metric: Metric | None = None,
    is_active: bool | None = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[GoalRead]:
    rows = await goal_service.list_goals(
        db, user.id, metric=metric, is_active=is_active, skip=offset, limit=limit
    )
    return [GoalRead.model_validate(r) for r in rows]


@router.post("", response_model=GoalRead, status_code=status.HTTP_201_CREATED)
async def create_goal(data: GoalCreate, user: CurrentUser, db: DbSession) -> GoalRead:
    try:
        return GoalRead.model_validate(await goal_service.create_goal(db, user.id, data))
    except goal_service.ActiveGoalExistsError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, CONFLICT) from exc


@router.patch("/{goal_id}", response_model=GoalRead)
async def update_goal(goal_id: int, data: GoalUpdate, user: CurrentUser, db: DbSession) -> GoalRead:
    try:
        row = await goal_service.update_goal(db, user.id, goal_id, data)
    except goal_service.ActiveGoalExistsError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, CONFLICT) from exc
    except ValueError as exc:  # target_value vượt ngưỡng của chỉ số
        raise HTTPException(422, str(exc)) from exc
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return GoalRead.model_validate(row)


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_goal(goal_id: int, user: CurrentUser, db: DbSession) -> Response:
    if not await goal_service.goal_crud.delete(db, goal_id, owner_id=user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
