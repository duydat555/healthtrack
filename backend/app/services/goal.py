"""Nghiệp vụ mục tiêu: mỗi chỉ số có tối đa một mục tiêu đang hoạt động."""

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.base import CRUDBase
from app.models.goal import Goal
from app.schemas.goal import GoalCreate, GoalUpdate, check_target

goal_crud = CRUDBase(Goal)


class ActiveGoalExistsError(Exception):
    """Chỉ số này đã có một mục tiêu đang hoạt động."""


async def list_goals(
    db: AsyncSession,
    user_id: int,
    *,
    metric: str | None = None,
    is_active: bool | None = None,
    skip: int = 0,
    limit: int = 50,
) -> list[Goal]:
    stmt = select(Goal).where(Goal.user_id == user_id)
    if metric is not None:
        stmt = stmt.where(Goal.metric == metric)
    if is_active is not None:
        stmt = stmt.where(Goal.is_active == is_active)
    stmt = stmt.order_by(Goal.id.desc()).offset(skip).limit(min(limit, 200))
    return list((await db.execute(stmt)).scalars().all())


async def _has_active(db: AsyncSession, user_id: int, metric: str, *, exclude_id: int = 0) -> bool:
    stmt = select(Goal.id).where(
        Goal.user_id == user_id, Goal.metric == metric, Goal.is_active, Goal.id != exclude_id
    )
    return (await db.execute(stmt)).first() is not None


async def create_goal(db: AsyncSession, user_id: int, data: GoalCreate) -> Goal:
    if await _has_active(db, user_id, data.metric):
        raise ActiveGoalExistsError(data.metric)
    try:
        return await goal_crud.create(db, data.model_dump(), owner_id=user_id)
    except IntegrityError as exc:  # hai request tạo cùng lúc
        await db.rollback()
        raise ActiveGoalExistsError(data.metric) from exc


async def update_goal(
    db: AsyncSession, user_id: int, goal_id: int, data: GoalUpdate
) -> Goal | None:
    goal = await goal_crud.get(db, goal_id, owner_id=user_id)
    if goal is None:
        return None
    changes = data.model_dump(exclude_unset=True, exclude_none=True)
    if "target_value" in changes:
        check_target(goal.metric, changes["target_value"])
    if changes.get("is_active") and not goal.is_active:
        if await _has_active(db, user_id, goal.metric, exclude_id=goal.id):
            raise ActiveGoalExistsError(goal.metric)
    try:
        return await goal_crud.update(db, goal_id, changes, owner_id=user_id)
    except IntegrityError as exc:
        await db.rollback()
        raise ActiveGoalExistsError(goal.metric) from exc
