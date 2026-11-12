from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.reminder import ReminderCreate, ReminderRead, ReminderUpdate
from app.services import reminder as reminder_service

router = APIRouter(prefix="/reminders", tags=["reminders"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
NOT_FOUND = "Không tìm thấy nhắc nhở"


@router.get("", response_model=list[ReminderRead])
async def list_reminders(
    user: CurrentUser,
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[ReminderRead]:
    rows = await reminder_service.list_reminders(db, user.id, skip=offset, limit=limit)
    return [ReminderRead.model_validate(row) for row in rows]


@router.post("", response_model=ReminderRead, status_code=status.HTTP_201_CREATED)
async def create_reminder(
    data: ReminderCreate, user: CurrentUser, db: DbSession
) -> ReminderRead:
    row = await reminder_service.create_reminder(db, user.id, data)
    return ReminderRead.model_validate(row)


@router.patch("/{reminder_id}", response_model=ReminderRead)
async def update_reminder(
    reminder_id: int, data: ReminderUpdate, user: CurrentUser, db: DbSession
) -> ReminderRead:
    row = await reminder_service.reminder_crud.update(
        db, reminder_id, data.model_dump(exclude_unset=True), owner_id=user.id
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return ReminderRead.model_validate(row)


@router.delete("/{reminder_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_reminder(reminder_id: int, user: CurrentUser, db: DbSession) -> Response:
    if not await reminder_service.reminder_crud.delete(db, reminder_id, owner_id=user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
