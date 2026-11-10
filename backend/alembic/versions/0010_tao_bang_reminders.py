"""Tạo bảng reminders.

Revision ID: 0010
Revises: 0009
Create Date: 2026-11-10
"""

import sqlalchemy as sa

from alembic import op

revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "reminders",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("kind", sa.String(length=20), nullable=False),
        sa.Column("at_time", sa.Time(), nullable=False),
        sa.Column("enabled", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_reminders_user_id_at_time", "reminders", ["user_id", "at_time"])


def downgrade() -> None:
    op.drop_index("ix_reminders_user_id_at_time", table_name="reminders")
    op.drop_table("reminders")
