from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Index, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class CoachInsight(Base):
    """Nhận xét tuần do AI Coach viết, lưu lại để không gọi lại model trong cùng tuần."""

    __tablename__ = "coach_insights"
    __table_args__ = (Index("uq_coach_insights_user_week", "user_id", "week_start", unique=True),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    week_start: Mapped[date] = mapped_column(Date)  # thứ hai của tuần (giờ địa phương)
    content: Mapped[str] = mapped_column(Text)
    model: Mapped[str] = mapped_column(String(60))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
