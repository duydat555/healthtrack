from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class MealLog(Base):
    __tablename__ = "meal_logs"
    __table_args__ = (Index("ix_meal_logs_user_id_logged_at", "user_id", "logged_at"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    meal_type: Mapped[str] = mapped_column(String(20))
    name: Mapped[str] = mapped_column(Text)
    calories: Mapped[int] = mapped_column(Integer)
    logged_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
