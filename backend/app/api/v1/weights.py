from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.weight import WeightCreate, WeightRead, WeightUpdate
from app.services import weight as weight_service

router = APIRouter(prefix="/weights", tags=["weights"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
NOT_FOUND = "Không tìm thấy bản ghi cân nặng"


@router.get("", response_model=list[WeightRead])
async def list_weights(
    user: CurrentUser,
    db: DbSession,
    from_: Annotated[datetime | None, Query(alias="from")] = None,
    to: datetime | None = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[WeightRead]:
    rows = await weight_service.weight_crud.list_in_range(
        db, user.id, "logged_at", from_, to, skip=offset, limit=limit
    )
    return [WeightRead.model_validate(r) for r in rows]


@router.post("", response_model=WeightRead, status_code=status.HTTP_201_CREATED)
async def create_weight(data: WeightCreate, user: CurrentUser, db: DbSession) -> WeightRead:
    return WeightRead.model_validate(await weight_service.create_weight(db, user, data))


@router.patch("/{weight_id}", response_model=WeightRead)
async def update_weight(
    weight_id: int, data: WeightUpdate, user: CurrentUser, db: DbSession
) -> WeightRead:
    row = await weight_service.update_weight(db, user, weight_id, data)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return WeightRead.model_validate(row)


@router.delete("/{weight_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_weight(weight_id: int, user: CurrentUser, db: DbSession) -> Response:
    if not await weight_service.weight_crud.delete(db, weight_id, owner_id=user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
