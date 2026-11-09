"""Cấu hình ứng dụng, đọc từ biến môi trường hoặc file .env."""

from functools import lru_cache

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_JWT_SECRET = "change-me-in-production"
MIN_JWT_SECRET_LENGTH = 32


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

    # Danh sách origin được gọi API, phân tách bằng dấu phẩy
    CORS_ORIGINS: str = "http://localhost:8080"

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
