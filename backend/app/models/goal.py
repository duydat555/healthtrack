from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Index, String, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Goal(Base):
    """Mục tiêu của người dùng cho một chỉ số theo chu kỳ ngày hoặc tuần.

    Mỗi (user, metric) chỉ có tối đa một mục tiêu đang hoạt động, được đảm bảo ở tầng CSDL
    bằng chỉ mục unique một phần (chỉ tính dòng `is_active`).
    """

    __tablename__ = "goals"
    __table_args__ = (
        Index(
            "uq_goals_user_metric_active",
            "user_id",
            "metric",
            unique=True,
            postgresql_where=text("is_active"),
            sqlite_where=text("is_active"),
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    metric: Mapped[str] = mapped_column(String(20))
    period: Mapped[str] = mapped_column(String(10))
    target_value: Mapped[float] = mapped_column(Float)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
