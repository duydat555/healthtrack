from fastapi import APIRouter

router = APIRouter(tags=["system"])


@router.get("/health")
async def health_check() -> dict[str, str]:
    """Kiểm tra API còn sống (dùng cho Docker healthcheck và Render)."""
    return {"status": "ok"}
