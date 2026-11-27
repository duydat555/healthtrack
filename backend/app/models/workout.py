from datetime import datetime

from sqlalchemy import JSON, DateTime, Float, ForeignKey, Index, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Workout(Base):
    """Một buổi tập ngoài trời (chạy bộ, đi bộ, đạp xe). Định dạng: docs/14."""

    __tablename__ = "workouts"
    __table_args__ = (
        Index("uq_workouts_user_workout_id", "user_id", "workout_id", unique=True),
        Index("ix_workouts_user_id_started_at", "user_id", "started_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    workout_id: Mapped[str] = mapped_column(String(64))  # id do app tạo (uuid)
    version: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    sport: Mapped[str] = mapped_column(String(8))
    title: Mapped[str] = mapped_column(String(120))
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ended_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    moving_seconds: Mapped[float] = mapped_column(Float)
    distance_m: Mapped[float] = mapped_column(Float)
    elevation_gain_m: Mapped[float] = mapped_column(Float)
    avg_pace_sec_per_km: Mapped[float | None] = mapped_column(Float)
    kcal: Mapped[float] = mapped_column(Float)
    splits: Mapped[list] = mapped_column(JSON, default=list)
    polyline: Mapped[str] = mapped_column(Text, default="", server_default="")
    points: Mapped[list | None] = mapped_column(JSON)  # điểm GPS đã lọc, có thể bỏ
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
