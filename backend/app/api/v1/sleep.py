from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.sleep import SleepCreate, SleepRead, SleepUpdate
from app.services import sleep as sleep_service

router = APIRouter(prefix="/sleep", tags=["sleep"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
NOT_FOUND = "Không tìm thấy bản ghi giấc ngủ"
INVALID_RANGE = "Giờ thức dậy phải sau giờ đi ngủ"


@router.get("", response_model=list[SleepRead])
async def list_sleep(
    user: CurrentUser,
    db: DbSession,
    from_: Annotated[datetime | None, Query(alias="from")] = None,
    to: datetime | None = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[SleepRead]:
    rows = await sleep_service.sleep_crud.list_in_range(
        db, user.id, "start_at", from_, to, skip=offset, limit=limit
    )
    return [SleepRead.model_validate(r) for r in rows]


@router.post("", response_model=SleepRead, status_code=status.HTTP_201_CREATED)
async def create_sleep(data: SleepCreate, user: CurrentUser, db: DbSession) -> SleepRead:
    try:
        row = await sleep_service.create_sleep(db, user.id, data)
    except sleep_service.InvalidSleepRangeError as exc:
        raise HTTPException(422, INVALID_RANGE) from exc
    return SleepRead.model_validate(row)


@router.patch("/{sleep_id}", response_model=SleepRead)
async def update_sleep(
    sleep_id: int, data: SleepUpdate, user: CurrentUser, db: DbSession
) -> SleepRead:
    try:
        row = await sleep_service.update_sleep(db, user.id, sleep_id, data)
    except sleep_service.InvalidSleepRangeError as exc:
        raise HTTPException(422, INVALID_RANGE) from exc
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return SleepRead.model_validate(row)


@router.delete("/{sleep_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_sleep(sleep_id: int, user: CurrentUser, db: DbSession) -> Response:
    if not await sleep_service.sleep_crud.delete(db, sleep_id, owner_id=user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
