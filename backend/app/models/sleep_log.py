from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class SleepLog(Base):
    __tablename__ = "sleep_logs"
    __table_args__ = (
        Index("ix_sleep_logs_user_id_start_at", "user_id", "start_at"),
        Index("ix_sleep_logs_user_id_end_at", "user_id", "end_at"),  # thống kê theo ngày thức dậy
        Index(
            "uq_sleep_logs_user_external_id",
            "user_id",
            "external_id",
            unique=True,
            postgresql_where=text("external_id IS NOT NULL"),
            sqlite_where=text("external_id IS NOT NULL"),
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    quality: Mapped[int | None] = mapped_column(Integer)
    source: Mapped[str] = mapped_column(String(12), default="manual", server_default="manual")
    external_id: Mapped[str | None] = mapped_column(String(64))  # UUID mẫu HealthKit
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
