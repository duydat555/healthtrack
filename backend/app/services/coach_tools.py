"""Công cụ cho AI Coach: đọc số liệu, đọc mục tiêu và ghi chỉ số bằng câu tự nhiên.

Mọi công cụ chạy với quyền của người dùng đang đăng nhập (``user_id`` lấy từ token, không bao
giờ từ model) và dùng lại đúng service của các endpoint thường, nên cùng quy tắc kiểm tra.
"""

import json
from datetime import UTC, datetime, timedelta
from typing import Any

from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.goal import Goal
from app.models.user import User
from app.schemas.meal import MealCreate
from app.schemas.sleep import SleepCreate
from app.schemas.step import StepCreate
from app.schemas.water import WaterCreate
from app.schemas.weight import WeightCreate
from app.services import meal as meal_service
from app.services import sleep as sleep_service
from app.services import step as step_service
from app.services import water as water_service
from app.services import weight as weight_service
from app.services.gamification import _days
from app.services.stats import daily_values, local_today

TOOLS: list[dict[str, Any]] = [
    {
        "name": "get_stats",
        "description": (
            "Lấy số liệu theo ngày của người dùng (nước ml, giấc ngủ phút, bước chân, cân nặng kg) "
            "trong N ngày gần nhất, ngày cũ trước. Ngày không ghi là null. Gọi trước khi nhận xét "
            "hoặc trả lời bất kỳ câu hỏi nào về số liệu."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "days": {"type": "integer", "minimum": 1, "maximum": 30, "description": "Số ngày"}
            },
            "required": ["days"],
            "additionalProperties": False,
        },
    },
    {
        "name": "get_goals",
        "description": "Lấy các mục tiêu đang hoạt động (chỉ số, chu kỳ ngày/tuần, giá trị đích).",
        "input_schema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "log_entry",
        "description": (
            "Ghi một chỉ số cho người dùng khi họ nói đã làm điều đó (ví dụ 'vừa uống 500ml'). "
            "Đơn vị của value: water = ml, weight = kg, steps = số bước, sleep = số giờ ngủ, "
            "meal = kcal. Với meal cần thêm name và meal_type. Không ghi nếu người dùng chỉ hỏi."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "metric": {"type": "string", "enum": ["water", "weight", "steps", "sleep", "meal"]},
                "value": {"type": "number", "exclusiveMinimum": 0},
                "logged_at": {
                    "type": "string",
                    "description": (
                        "ISO 8601 có múi giờ; bỏ trống là bây giờ. Với sleep là giờ thức dậy."
                    ),
                },
                "name": {"type": "string", "description": "Tên món (chỉ với meal)"},
                "meal_type": {
                    "type": "string",
                    "enum": ["breakfast", "lunch", "dinner", "snack"],
                },
            },
            "required": ["metric", "value"],
            "additionalProperties": False,
        },
    },
]


def _parse_when(raw: str | None) -> datetime:
    if not raw:
        return datetime.now(UTC)
    when = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    return when if when.tzinfo else when.replace(tzinfo=UTC)


async def get_stats(db: AsyncSession, user: User, days: int, tz_offset: int) -> dict[str, Any]:
    days = max(1, min(int(days), 30))
    end = local_today(tz_offset)
    start = end - timedelta(days=days - 1)
    per_day = await _days(db, user.id, start, end, tz_offset)
    weight = await daily_values(db, user.id, "weight", start, end, tz_offset)
    rows = []
    for i in range(days):
        d = start + timedelta(days=i)
        v = per_day[d]
        rows.append(
            {
                "date": d.isoformat(),
                "water_ml": v.water or None,
                "sleep_minutes": v.sleep or None,
                "steps": v.steps or None,
                "weight_kg": weight.get(d),
            }
        )
    return {"unit_note": "null = ngày không có dữ liệu", "days": rows}


async def get_goals(db: AsyncSession, user: User) -> dict[str, Any]:
    goals = (
        await db.execute(select(Goal).where(Goal.user_id == user.id, Goal.is_active))
    ).scalars()
    return {
        "goals": [
            {"metric": g.metric, "period": g.period, "target_value": g.target_value} for g in goals
        ]
    }


async def log_entry(
    db: AsyncSession, user: User, args: dict[str, Any], tz_offset: int
) -> dict[str, Any]:
    metric, value = args["metric"], float(args["value"])
    when = _parse_when(args.get("logged_at"))
    if metric == "water":
        await water_service.water_crud.create(
            db, WaterCreate(amount_ml=round(value), logged_at=when).model_dump(), owner_id=user.id
        )
    elif metric == "weight":
        await weight_service.create_weight(db, user, WeightCreate(weight_kg=value, logged_at=when))
    elif metric == "steps":
        local_day = (when + timedelta(minutes=tz_offset)).date()
        await step_service.upsert_step(db, user.id, StepCreate(steps=round(value), day=local_day))
    elif metric == "sleep":
        await sleep_service.create_sleep(
            db, user.id, SleepCreate(start_at=when - timedelta(hours=value), end_at=when)
        )
    elif metric == "meal":
        await meal_service.create_meal(
            db,
            user.id,
            MealCreate(
                meal_type=args.get("meal_type") or "snack",
                name=args.get("name") or "Bữa ăn",
                calories=round(value),
                logged_at=when,
            ),
        )
    else:
        raise ValueError(f"Chỉ số không hỗ trợ: {metric}")
    return {"ok": True, "metric": metric, "value": value}


async def run_tool(
    db: AsyncSession, user: User, name: str, args: dict[str, Any], tz_offset: int
) -> tuple[str, bool]:
    """Chạy một công cụ; trả (nội dung JSON, có lỗi không). Lỗi trả về cho model đọc, không ném."""
    try:
        if name == "get_stats":
            result = await get_stats(db, user, args.get("days", 7), tz_offset)
        elif name == "get_goals":
            result = await get_goals(db, user)
        elif name == "log_entry":
            result = await log_entry(db, user, args, tz_offset)
        else:
            return json.dumps({"error": f"Công cụ không tồn tại: {name}"}), True
        return json.dumps(result, ensure_ascii=False), False
    except (ValidationError, ValueError, KeyError, TypeError) as e:
        await db.rollback()
        return json.dumps({"error": f"Dữ liệu không hợp lệ: {e}"}, ensure_ascii=False), True
