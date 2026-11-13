"""Import mọi model ở đây để Alembic nhận diện."""

from app.models.achievement import Achievement
from app.models.goal import Goal
from app.models.meal_log import MealLog
from app.models.medication import Medication, MedicationLog
from app.models.reminder import Reminder
from app.models.sleep_log import SleepLog
from app.models.step_log import StepLog
from app.models.user import User
from app.models.water_log import WaterLog
from app.models.weight_log import WeightLog

__all__ = [
    "Achievement",
    "Goal",
    "Medication",
    "MedicationLog",
    "MealLog",
    "Reminder",
    "SleepLog",
    "StepLog",
    "User",
    "WaterLog",
    "WeightLog",
]
