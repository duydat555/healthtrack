from datetime import UTC, date, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.core.db import get_db
from app.schemas.water import WaterCreate, WaterDailyTotal, WaterRead, WaterUpdate
from app.services import water as water_service

router = APIRouter(prefix="/water", tags=["water"])
DbSession = Annotated[AsyncSession, Depends(get_db)]
NOT_FOUND = "Không tìm thấy bản ghi nước uống"


@router.get("", response_model=list[WaterRead])
async def list_water(
    user: CurrentUser,
    db: DbSession,
    from_: Annotated[datetime | None, Query(alias="from")] = None,
    to: datetime | None = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[WaterRead]:
    rows = await water_service.water_crud.list_in_range(
        db, user.id, "logged_at", from_, to, skip=offset, limit=limit
    )
    return [WaterRead.model_validate(r) for r in rows]


@router.get("/total", response_model=WaterDailyTotal)
async def daily_total(
    user: CurrentUser, db: DbSession, day: Annotated[date | None, Query(alias="date")] = None
) -> WaterDailyTotal:
    """Tổng lượng nước trong một ngày (UTC); mặc định là hôm nay."""
    day = day or datetime.now(UTC).date()
    return WaterDailyTotal(date=day, total_ml=await water_service.daily_total_ml(db, user.id, day))


@router.post("", response_model=WaterRead, status_code=status.HTTP_201_CREATED)
async def create_water(data: WaterCreate, user: CurrentUser, db: DbSession) -> WaterRead:
    values = {
        "amount_ml": data.amount_ml,
        "logged_at": data.logged_at or datetime.now(UTC),
    }
    row = await water_service.water_crud.create(db, values, owner_id=user.id)
    return WaterRead.model_validate(row)


@router.patch("/{water_id}", response_model=WaterRead)
async def update_water(
    water_id: int, data: WaterUpdate, user: CurrentUser, db: DbSession
) -> WaterRead:
    changes = data.model_dump(exclude_unset=True, exclude_none=True)
    row = await water_service.water_crud.update(db, water_id, changes, owner_id=user.id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return WaterRead.model_validate(row)


@router.delete("/{water_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_water(water_id: int, user: CurrentUser, db: DbSession) -> Response:
    if not await water_service.water_crud.delete(db, water_id, owner_id=user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
