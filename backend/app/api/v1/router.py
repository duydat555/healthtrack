"""Gom tất cả router của API v1. Router mới thì include vào đây."""

from fastapi import APIRouter

from app.api.v1 import (
    auth,
    coach,
    gamification,
    goals,
    health,
    meals,
    medications,
    reminders,
    sleep,
    stats,
    steps,
    sync,
    users,
    water,
    weights,
)

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(weights.router)
api_router.include_router(water.router)
api_router.include_router(sleep.router)
api_router.include_router(steps.router)
api_router.include_router(meals.router)
api_router.include_router(medications.router)
api_router.include_router(reminders.router)
api_router.include_router(goals.router)
api_router.include_router(stats.router)
api_router.include_router(gamification.router)
api_router.include_router(sync.router)
api_router.include_router(coach.router)
