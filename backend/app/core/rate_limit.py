"""Giới hạn tốc độ (sliding window) lưu trong bộ nhớ của tiến trình.

Phù hợp khi chạy một instance. Nếu mở rộng nhiều instance cần chuyển sang Redis.
"""

import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status

from app.core.config import settings

# Quá số IP này thì dọn các mục đã hết hạn, để bộ nhớ không tăng mãi theo số IP từng gọi
MAX_TRACKED_KEYS = 10_000


class RateLimiter:
    def __init__(self, max_requests: int, window_seconds: int) -> None:
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def hit(self, key: str) -> int:
        """Ghi một lượt gọi; trả 0 nếu được phép, ngược lại trả số giây cần chờ."""
        now = time.monotonic()
        if len(self._hits) > MAX_TRACKED_KEYS:
            self._purge(now)
        hits = self._hits[key]
        while hits and now - hits[0] >= self.window_seconds:
            hits.popleft()
        if len(hits) >= self.max_requests:
            return max(1, int(self.window_seconds - (now - hits[0])) + 1)
        hits.append(now)
        return 0

    def _purge(self, now: float) -> None:
        """Xóa các IP không còn lượt gọi nào trong cửa sổ thời gian."""
        expired = [k for k, h in self._hits.items() if not h or now - h[-1] >= self.window_seconds]
        for k in expired:
            del self._hits[k]

    def reset(self) -> None:
        self._hits.clear()


login_limiter = RateLimiter(settings.LOGIN_RATE_LIMIT, settings.LOGIN_RATE_WINDOW_SECONDS)


async def limit_login(request: Request) -> None:
    """Dependency cho /auth/login: giới hạn theo địa chỉ IP, vượt ngưỡng trả 429."""
    client_ip = request.client.host if request.client else "unknown"
    retry_after = login_limiter.hit(client_ip)
    if retry_after:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Đăng nhập quá nhiều lần, vui lòng thử lại sau",
            headers={"Retry-After": str(retry_after)},
        )
