"""Cấu hình logging chung cho toàn bộ ứng dụng."""

import logging
import sys

from app.core.config import settings

LOG_FORMAT = "%(asctime)s %(levelname)s %(name)s: %(message)s"


def setup_logging() -> None:
    """Ghi log ra stdout; DEBUG ở môi trường development, INFO ở môi trường khác."""
    level = logging.DEBUG if settings.ENV == "development" else logging.INFO
    logging.basicConfig(
        level=level,
        format=LOG_FORMAT,
        handlers=[logging.StreamHandler(sys.stdout)],
        force=True,
    )
    # Giảm nhiễu từ thư viện
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
