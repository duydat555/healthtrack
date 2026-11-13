"""Tạo bảng achievements.

Revision ID: 0011
Revises: 0010
Create Date: 2026-11-13
"""

import sqlalchemy as sa

from alembic import op

revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "achievements",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("code", sa.String(length=40), nullable=False),
        sa.Column(
            "earned_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("uq_achievements_user_code", "achievements", ["user_id", "code"], unique=True)


def downgrade() -> None:
    op.drop_index("uq_achievements_user_code", table_name="achievements")
    op.drop_table("achievements")
