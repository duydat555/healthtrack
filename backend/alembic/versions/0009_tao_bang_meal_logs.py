"""tạo bảng meal_logs

Revision ID: 0009
Revises: 0008
Create Date: 2026-11-10
"""

import sqlalchemy as sa

from alembic import op

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "meal_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("meal_type", sa.String(length=20), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("calories", sa.Integer(), nullable=False),
        sa.Column("logged_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_meal_logs_user_id_logged_at", "meal_logs", ["user_id", "logged_at"])


def downgrade() -> None:
    op.drop_index("ix_meal_logs_user_id_logged_at", table_name="meal_logs")
    op.drop_table("meal_logs")
