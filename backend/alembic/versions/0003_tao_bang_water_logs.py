"""tạo bảng water_logs

Revision ID: 0003
Revises: 0002
Create Date: 2026-11-09
"""

import sqlalchemy as sa

from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "water_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("amount_ml", sa.Integer(), nullable=False),
        sa.Column("logged_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_water_logs_user_id_logged_at", "water_logs", ["user_id", "logged_at"])


def downgrade() -> None:
    op.drop_index("ix_water_logs_user_id_logged_at", table_name="water_logs")
    op.drop_table("water_logs")
