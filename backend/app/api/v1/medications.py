from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.medication import (
    MedicationCreate,
    MedicationLogCreate,
    MedicationLogRead,
    MedicationRead,
    MedicationUpdate,
)
from app.services import medication as med_service

router = APIRouter(prefix="/medications", tags=["medications"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
NOT_FOUND = "Không tìm thấy thuốc"


@router.get("", response_model=list[MedicationRead])
async def list_medications(
    user: CurrentUser,
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[MedicationRead]:
    rows = await med_service.medication_crud.list(db, user.id, skip=offset, limit=limit)
    return [MedicationRead.model_validate(r) for r in rows]


@router.post("", response_model=MedicationRead, status_code=status.HTTP_201_CREATED)
async def create_medication(
    data: MedicationCreate, user: CurrentUser, db: DbSession
) -> MedicationRead:
    row = await med_service.medication_crud.create(db, data.model_dump(), owner_id=user.id)
    return MedicationRead.model_validate(row)


@router.patch("/{medication_id}", response_model=MedicationRead)
async def update_medication(
    medication_id: int, data: MedicationUpdate, user: CurrentUser, db: DbSession
) -> MedicationRead:
    changes = data.model_dump(exclude_unset=True)
    for required in ("name", "is_active"):  # hai cột này không được null
        if changes.get(required, 0) is None:
            changes.pop(required)
    row = await med_service.medication_crud.update(db, medication_id, changes, owner_id=user.id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return MedicationRead.model_validate(row)


@router.delete("/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_medication(medication_id: int, user: CurrentUser, db: DbSession) -> Response:
    if not await med_service.medication_crud.delete(db, medication_id, owner_id=user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{medication_id}/logs", response_model=MedicationLogRead, status_code=status.HTTP_201_CREATED
)
async def add_medication_log(
    medication_id: int, data: MedicationLogCreate, user: CurrentUser, db: DbSession
) -> MedicationLogRead:
    row = await med_service.add_log(db, user.id, medication_id, data)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return MedicationLogRead.model_validate(row)


@router.get("/{medication_id}/logs", response_model=list[MedicationLogRead])
async def list_medication_logs(
    medication_id: int,
    user: CurrentUser,
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[MedicationLogRead]:
    rows = await med_service.list_logs(db, user.id, medication_id, skip=offset, limit=limit)
    if rows is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return [MedicationLogRead.model_validate(r) for r in rows]
