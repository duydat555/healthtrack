"""Tạo bảng workouts (buổi tập ngoài trời, Phase 8).

Revision ID: 0014
Revises: 0013
Create Date: 2026-11-27
"""

import sqlalchemy as sa

from alembic import op

revision = "0014"
down_revision = "0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "workouts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("workout_id", sa.String(length=64), nullable=False),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
        sa.Column("sport", sa.String(length=8), nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("moving_seconds", sa.Float(), nullable=False),
        sa.Column("distance_m", sa.Float(), nullable=False),
        sa.Column("elevation_gain_m", sa.Float(), nullable=False),
        sa.Column("avg_pace_sec_per_km", sa.Float(), nullable=True),
        sa.Column("kcal", sa.Float(), nullable=False),
        sa.Column("splits", sa.JSON(), nullable=False),
        sa.Column("polyline", sa.Text(), server_default="", nullable=False),
        sa.Column("points", sa.JSON(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index(
        "uq_workouts_user_workout_id", "workouts", ["user_id", "workout_id"], unique=True
    )
    op.create_index("ix_workouts_user_id_started_at", "workouts", ["user_id", "started_at"])


def downgrade() -> None:
    op.drop_index("ix_workouts_user_id_started_at", table_name="workouts")
    op.drop_index("uq_workouts_user_workout_id", table_name="workouts")
    op.drop_table("workouts")
