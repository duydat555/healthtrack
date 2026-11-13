"""Thêm source và external_id cho steps, sleep, weights (đồng bộ HealthKit không trùng).

Revision ID: 0012
Revises: 0011
Create Date: 2026-11-13
"""

import sqlalchemy as sa

from alembic import op

revision = "0012"
down_revision = "0011"
branch_labels = None
depends_on = None

_SOURCE = dict(nullable=False, server_default="manual")


def upgrade() -> None:
    op.add_column("step_logs", sa.Column("source", sa.String(length=12), **_SOURCE))
    for table in ("sleep_logs", "weight_logs"):
        op.add_column(table, sa.Column("source", sa.String(length=12), **_SOURCE))
        op.add_column(table, sa.Column("external_id", sa.String(length=64), nullable=True))
        op.create_index(
            f"uq_{table}_user_external_id",
            table,
            ["user_id", "external_id"],
            unique=True,
            postgresql_where=sa.text("external_id IS NOT NULL"),
        )


def downgrade() -> None:
    for table in ("weight_logs", "sleep_logs"):
        op.drop_index(f"uq_{table}_user_external_id", table_name=table)
        op.drop_column(table, "external_id")
        op.drop_column(table, "source")
    op.drop_column("step_logs", "source")
