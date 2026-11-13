from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Achievement(Base):
    """Huy hiệu người dùng đã đạt. Mỗi (user, code) chỉ có một dòng."""

    __tablename__ = "achievements"
    __table_args__ = (Index("uq_achievements_user_code", "user_id", "code", unique=True),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    code: Mapped[str] = mapped_column(String(40))
    earned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
