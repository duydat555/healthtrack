from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.schemas.user import UserCreate, UserRead
from app.services import auth as auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def register(data: UserCreate, db: Annotated[AsyncSession, Depends(get_db)]) -> UserRead:
    try:
        user = await auth_service.register_user(db, data)
    except auth_service.EmailAlreadyExistsError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, "Email đã được đăng ký") from exc
    return UserRead.model_validate(user)
