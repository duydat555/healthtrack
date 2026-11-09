"""tạo bảng medications và medication_logs

Revision ID: 0005
Revises: 0004
Create Date: 2026-11-09
"""

import sqlalchemy as sa

from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "medications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("dosage", sa.String(100), nullable=True),
        sa.Column("schedule", sa.String(255), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_medications_user_id", "medications", ["user_id"])
    op.create_table(
        "medication_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "medication_id",
            sa.Integer(),
            sa.ForeignKey("medications.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("taken_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("taken", sa.Boolean(), server_default="true", nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index(
        "ix_medication_logs_medication_id_taken_at",
        "medication_logs",
        ["medication_id", "taken_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_medication_logs_medication_id_taken_at", table_name="medication_logs")
    op.drop_table("medication_logs")
    op.drop_index("ix_medications_user_id", table_name="medications")
    op.drop_table("medications")
