"""Gom tất cả router của API v1. Router mới thì include vào đây."""

from fastapi import APIRouter

from app.api.v1 import auth, goals, health, medications, sleep, stats, steps, users, water, weights

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(weights.router)
api_router.include_router(water.router)
api_router.include_router(sleep.router)
api_router.include_router(steps.router)
api_router.include_router(medications.router)
api_router.include_router(goals.router)
api_router.include_router(stats.router)
