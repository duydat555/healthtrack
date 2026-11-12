from datetime import datetime, time

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, String, Time, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Reminder(Base):
    __tablename__ = "reminders"
    __table_args__ = (Index("ix_reminders_user_id_at_time", "user_id", "at_time"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    kind: Mapped[str] = mapped_column(String(20))
    at_time: Mapped[time] = mapped_column(Time())
    enabled: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
