import logging
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db

logger = logging.getLogger(__name__)
router = APIRouter(tags=["system"])


@router.get("/health")
async def health_check() -> dict[str, str]:
    """Kiểm tra API còn sống (dùng cho Docker healthcheck và Render)."""
    return {"status": "ok"}


@router.get("/health/ready")
async def health_ready(db: Annotated[AsyncSession, Depends(get_db)]) -> dict[str, str]:
    """Kiểm tra API sẵn sàng phục vụ: kết nối được CSDL."""
    try:
        await db.execute(text("SELECT 1"))
    except Exception as exc:
        logger.error("Kiểm tra CSDL thất bại: %s", exc)
        raise HTTPException(status_code=503, detail="Cơ sở dữ liệu chưa sẵn sàng") from exc
    return {"status": "ready", "database": "ok"}
