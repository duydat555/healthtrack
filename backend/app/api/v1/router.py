"""Gom tất cả router của API v1. Router mới thì include vào đây."""

from fastapi import APIRouter

from app.api.v1 import health

api_router = APIRouter()
api_router.include_router(health.router)
