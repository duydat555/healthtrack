"""tạo bảng goals

Revision ID: 0006
Revises: 0005
Create Date: 2026-11-09
"""

import sqlalchemy as sa

from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "goals",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("metric", sa.String(20), nullable=False),
        sa.Column("period", sa.String(10), nullable=False),
        sa.Column("target_value", sa.Float(), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    # Mỗi (user, metric) tối đa một mục tiêu đang hoạt động
    op.create_index(
        "uq_goals_user_metric_active",
        "goals",
        ["user_id", "metric"],
        unique=True,
        postgresql_where=sa.text("is_active"),
        sqlite_where=sa.text("is_active"),
    )


def downgrade() -> None:
    op.drop_index("uq_goals_user_metric_active", table_name="goals")
    op.drop_table("goals")
