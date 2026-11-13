"""Cấu hình ứng dụng, đọc từ biến môi trường hoặc file .env."""

from functools import lru_cache
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_JWT_SECRET = "change-me-in-production"
MIN_JWT_SECRET_LENGTH = 32


def normalize_database_url(url: str) -> str:
    """Đưa chuỗi kết nối PostgreSQL của nhà cung cấp (Neon, Supabase, Render) về dạng asyncpg.

    - `postgres://` và `postgresql://` thành `postgresql+asyncpg://` (đã có driver thì giữ nguyên).
    - asyncpg không hiểu `sslmode` và `channel_binding` của libpq: `sslmode=X` đổi thành `ssl=X`,
      `channel_binding` bị bỏ.
    """
    parts = urlsplit(url)
    scheme = parts.scheme
    if scheme in ("postgres", "postgresql"):
        scheme = "postgresql+asyncpg"
    query = []
    for key, value in parse_qsl(parts.query, keep_blank_values=True):
        if key == "channel_binding":
            continue
        query.append(("ssl" if key == "sslmode" else key, value))
    return urlunsplit((scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_NAME: str = "HealthTrack API"
    ENV: str = "development"
    API_V1_PREFIX: str = "/api/v1"

    DATABASE_URL: str = "postgresql+asyncpg://healthtrack:healthtrack@db:5432/healthtrack"

    JWT_SECRET: str = DEFAULT_JWT_SECRET
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Giới hạn đăng nhập: tối đa N lượt mỗi IP trong cửa sổ thời gian
    LOGIN_RATE_LIMIT: int = 10
    LOGIN_RATE_WINDOW_SECONDS: int = 60
    # Request chậm hơn ngưỡng này (ms) sẽ bị ghi cảnh báo
    SLOW_REQUEST_MS: int = 500

    # AI Coach (Claude). Để trống thì /coach trả 503, các phần khác của API vẫn chạy bình thường.
    ANTHROPIC_API_KEY: str = ""
    COACH_CHAT_MODEL: str = "claude-haiku-5-5"
    COACH_WEEKLY_MODEL: str = "claude-sonnet-5-5"
    # AI local: server MLX trên Mac (scripts/local-llm.sh). Trong Docker dùng
    # http://host.docker.internal:8090/v1. Để trống thì tắt chế độ riêng tư.
    LOCAL_LLM_URL: str = ""
    LOCAL_LLM_MODEL: str = "mlx-community/Qwen3.5-9B-MLX-4bit"
    LOCAL_LLM_API_KEY: str = ""
    LOCAL_LLM_TIMEOUT_SECONDS: int = 120
    COACH_RATE_LIMIT: int = 20
    COACH_RATE_WINDOW_SECONDS: int = 60

    # Danh sách origin được gọi API, phân tách bằng dấu phẩy
    CORS_ORIGINS: str = "http://localhost:8080"

    @field_validator("DATABASE_URL")
    @classmethod
    def _normalize_database_url(cls, value: str) -> str:
        return normalize_database_url(value)

    @model_validator(mode="after")
    def _check_production_security(self) -> "Settings":
        """Môi trường production không được chạy với cấu hình bảo mật mặc định."""
        if self.ENV != "production":
            return self
        if self.JWT_SECRET == DEFAULT_JWT_SECRET or len(self.JWT_SECRET) < MIN_JWT_SECRET_LENGTH:
            raise ValueError(
                f"JWT_SECRET phải riêng và dài từ {MIN_JWT_SECRET_LENGTH} ký tự ở production"
            )
        if "*" in self.cors_origins_list:
            raise ValueError("CORS_ORIGINS không được dùng '*' ở production")
        return self

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
