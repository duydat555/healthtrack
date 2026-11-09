"""tạo bảng weight_logs

Revision ID: 0002
Revises: 0001
Create Date: 2026-11-09
"""

import sqlalchemy as sa

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "weight_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("weight_kg", sa.Float(), nullable=False),
        sa.Column("bmi", sa.Float(), nullable=True),
        sa.Column("logged_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_weight_logs_user_id_logged_at", "weight_logs", ["user_id", "logged_at"])


def downgrade() -> None:
    op.drop_index("ix_weight_logs_user_id_logged_at", table_name="weight_logs")
    op.drop_table("weight_logs")
