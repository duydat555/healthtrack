"""thêm chỉ mục sleep_logs (user_id, end_at) cho thống kê theo ngày

Revision ID: 0007
Revises: 0006
Create Date: 2026-11-09
"""

from alembic import op

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index("ix_sleep_logs_user_id_end_at", "sleep_logs", ["user_id", "end_at"])


def downgrade() -> None:
    op.drop_index("ix_sleep_logs_user_id_end_at", table_name="sleep_logs")
