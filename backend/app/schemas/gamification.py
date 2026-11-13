from datetime import datetime

from pydantic import BaseModel


class ScoreComponent(BaseModel):
    metric: str
    percent: float  # 0 đến 100, đã giới hạn ở 100


class WeeklyChallenge(BaseModel):
    code: str
    title: str
    progress: int
    target: int


class GamificationSummary(BaseModel):
    score: int  # Health Score 0 đến 100 của hôm nay
    components: list[ScoreComponent]
    streak: int  # số ngày liên tiếp đạt từ 70 điểm
    best_streak: int
    challenge: WeeklyChallenge
    new_achievements: list[str]  # mã huy hiệu vừa đạt trong lần gọi này


class AchievementOut(BaseModel):
    code: str
    title: str
    description: str
    earned_at: datetime | None  # null = chưa đạt
