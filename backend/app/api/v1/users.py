from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.crud.user import user_crud
from app.schemas.user import UserRead, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserRead)
async def read_me(current_user: CurrentUser) -> UserRead:
    return UserRead.model_validate(current_user)


@router.patch("/me", response_model=UserRead)
async def update_me(
    data: UserUpdate, current_user: CurrentUser, db: Annotated[AsyncSession, Depends(get_db)]
) -> UserRead:
    changes = data.model_dump(exclude_unset=True)
    if changes.get("full_name") is None:
        changes.pop("full_name", None)  # cột full_name không được null
    updated = await user_crud.update(db, current_user.id, changes)
    return UserRead.model_validate(updated)
