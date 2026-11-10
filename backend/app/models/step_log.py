from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Index, Integer, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class StepLog(Base):
    __tablename__ = "step_logs"
    __table_args__ = (Index("uq_step_logs_user_day", "user_id", "day", unique=True),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    steps: Mapped[int] = mapped_column(Integer)
    day: Mapped[date] = mapped_column(Date)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
