from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class WaterLog(Base):
    __tablename__ = "water_logs"
    __table_args__ = (Index("ix_water_logs_user_id_logged_at", "user_id", "logged_at"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    amount_ml: Mapped[int] = mapped_column(Integer)
    logged_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
