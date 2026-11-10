from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.step import StepCreate, StepRead, StepUpdate
from app.services import step as step_service

router = APIRouter(prefix="/steps", tags=["steps"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
NOT_FOUND = "Không tìm thấy bản ghi bước chân"


@router.get("", response_model=list[StepRead])
async def list_steps(
    user: CurrentUser,
    db: DbSession,
    from_: Annotated[date | None, Query(alias="from")] = None,
    to: date | None = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[StepRead]:
    if from_ is not None and to is not None and from_ > to:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY, "'from' phải trước hoặc bằng 'to'"
        )
    rows = await step_service.list_steps(db, user.id, from_, to, skip=offset, limit=limit)
    return [StepRead.model_validate(row) for row in rows]


@router.post("", response_model=StepRead)
async def upsert_steps(
    data: StepCreate, user: CurrentUser, db: DbSession, response: Response
) -> StepRead:
    row, created = await step_service.upsert_step(db, user.id, data)
    response.status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
    return StepRead.model_validate(row)


@router.patch("/{step_id}", response_model=StepRead)
async def update_steps(
    step_id: int, data: StepUpdate, user: CurrentUser, db: DbSession
) -> StepRead:
    try:
        row = await step_service.update_step(db, user.id, step_id, data)
    except step_service.DuplicateStepDayError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, "Ngày đã có bản ghi bước chân") from exc
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return StepRead.model_validate(row)


@router.delete("/{step_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_steps(step_id: int, user: CurrentUser, db: DbSession) -> Response:
    if not await step_service.step_crud.delete(db, step_id, owner_id=user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
