from collections.abc import AsyncGenerator

from fastapi import APIRouter, FastAPI, HTTPException
from httpx import ASGITransport, AsyncClient
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.db import get_db
from app.main import app


def make_client(target: FastAPI) -> AsyncClient:
    return AsyncClient(
        transport=ASGITransport(app=target, raise_app_exceptions=False), base_url="http://test"
    )


class Item(BaseModel):
    qty: int


_router = APIRouter(prefix="/_test")


@_router.get("/not-found")
async def _not_found() -> None:
    raise HTTPException(status_code=404, detail="Không tìm thấy")


@_router.get("/boom")
async def _boom() -> None:
    raise RuntimeError("bug")


@_router.post("/items")
async def _items(item: Item) -> Item:
    return item


app.include_router(_router)


async def test_http_error_returns_detail() -> None:
    async with make_client(app) as client:
        res = await client.get("/_test/not-found")
    assert res.status_code == 404
    assert res.json() == {"detail": "Không tìm thấy"}


async def test_unknown_route_returns_detail() -> None:
    async with make_client(app) as client:
        res = await client.get("/khong-ton-tai")
    assert res.status_code == 404
    assert "detail" in res.json()


async def test_validation_error_returns_422_detail() -> None:
    async with make_client(app) as client:
        res = await client.post("/_test/items", json={"qty": "abc"})
    assert res.status_code == 422
    assert isinstance(res.json()["detail"], list)


async def test_unhandled_error_returns_500_detail() -> None:
    async with make_client(app) as client:
        res = await client.get("/_test/boom")
    assert res.status_code == 500
    assert res.json() == {"detail": "Lỗi máy chủ nội bộ"}


async def test_ready_ok_when_db_reachable() -> None:
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    maker = async_sessionmaker(engine, expire_on_commit=False)

    async def override() -> AsyncGenerator[AsyncSession, None]:
        async with maker() as session:
            yield session

    app.dependency_overrides[get_db] = override
    try:
        async with make_client(app) as client:
            res = await client.get("/api/v1/health/ready")
    finally:
        app.dependency_overrides.clear()
        await engine.dispose()
    assert res.status_code == 200
    assert res.json() == {"status": "ready", "database": "ok"}


async def test_ready_503_when_db_down() -> None:
    class BrokenSession:
        async def execute(self, *_: object) -> None:
            raise ConnectionError("db down")

    async def override() -> AsyncGenerator[BrokenSession, None]:
        yield BrokenSession()

    app.dependency_overrides[get_db] = override
    try:
        async with make_client(app) as client:
            res = await client.get("/api/v1/health/ready")
    finally:
        app.dependency_overrides.clear()
    assert res.status_code == 503
    assert res.json() == {"detail": "Cơ sở dữ liệu chưa sẵn sàng"}
