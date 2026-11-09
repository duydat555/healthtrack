"""Import mọi model ở đây để Alembic nhận diện."""

from app.models.goal import Goal
from app.models.medication import Medication, MedicationLog
from app.models.sleep_log import SleepLog
from app.models.user import User
from app.models.water_log import WaterLog
from app.models.weight_log import WeightLog

__all__ = ["Goal", "Medication", "MedicationLog", "SleepLog", "User", "WaterLog", "WeightLog"]
