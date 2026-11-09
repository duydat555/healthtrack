from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Index, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class WeightLog(Base):
    __tablename__ = "weight_logs"
    __table_args__ = (Index("ix_weight_logs_user_id_logged_at", "user_id", "logged_at"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    weight_kg: Mapped[float] = mapped_column(Float)
    bmi: Mapped[float | None] = mapped_column(Float)
    logged_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
