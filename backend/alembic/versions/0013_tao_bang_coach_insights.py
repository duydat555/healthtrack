"""Tạo bảng coach_insights.

Revision ID: 0013
Revises: 0012
Create Date: 2026-11-13
"""

import sqlalchemy as sa

from alembic import op

revision = "0013"
down_revision = "0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "coach_insights",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("week_start", sa.Date(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("model", sa.String(length=60), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index(
        "uq_coach_insights_user_week", "coach_insights", ["user_id", "week_start"], unique=True
    )


def downgrade() -> None:
    op.drop_index("uq_coach_insights_user_week", table_name="coach_insights")
    op.drop_table("coach_insights")
