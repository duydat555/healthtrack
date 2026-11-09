"""tạo bảng sleep_logs

Revision ID: 0004
Revises: 0003
Create Date: 2026-11-09
"""

import sqlalchemy as sa

from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sleep_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("quality", sa.Integer(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_sleep_logs_user_id_start_at", "sleep_logs", ["user_id", "start_at"])


def downgrade() -> None:
    op.drop_index("ix_sleep_logs_user_id_start_at", table_name="sleep_logs")
    op.drop_table("sleep_logs")
