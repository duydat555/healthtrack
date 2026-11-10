"""tạo bảng step_logs

Revision ID: 0008
Revises: 0007
Create Date: 2026-11-10
"""

import sqlalchemy as sa

from alembic import op

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "step_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("steps", sa.Integer(), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("uq_step_logs_user_day", "step_logs", ["user_id", "day"], unique=True)


def downgrade() -> None:
    op.drop_index("uq_step_logs_user_day", table_name="step_logs")
    op.drop_table("step_logs")
