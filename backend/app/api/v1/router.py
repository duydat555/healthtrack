"""Gom tất cả router của API v1. Router mới thì include vào đây."""

from fastapi import APIRouter

from app.api.v1 import auth, health, sleep, users, water, weights

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(weights.router)
api_router.include_router(water.router)
api_router.include_router(sleep.router)
