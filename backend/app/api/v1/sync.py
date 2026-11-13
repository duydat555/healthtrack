from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.sync import HealthKitSync, HealthKitSyncResult
from app.services import sync as sync_service

router = APIRouter(prefix="/sync", tags=["sync"])
DbSession = Annotated[AsyncSession, Depends(get_db)]


@router.post("/healthkit", response_model=HealthKitSyncResult)
async def sync_healthkit(
    data: HealthKitSync, user: CurrentUser, db: DbSession
) -> HealthKitSyncResult:
    """Nhận theo lô dữ liệu từ Apple Health; gọi lại cùng dữ liệu thì cập nhật, không nhân đôi."""
    return await sync_service.sync_healthkit(db, user, data)
