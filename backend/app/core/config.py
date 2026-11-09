# =============================================================================
# CORE: CẤU HÌNH ỨNG DỤNG
# =============================================================================
#
# FLOW
#   1. Đọc biến môi trường, sau đó đọc `backend/.env`. Biến môi trường được ưu tiên.
#   2. Kiểm tra giá trị; thiếu JWT_SECRET thì BE dừng ngay khi khởi động.
#
# LƯU Ý
#   GEMINI_API_KEY (hoặc GOOGLE_API_KEY, ANTHROPIC_API_KEY) để trống vẫn hợp lệ: khi đó thực đơn tạo theo quy tắc.
# =============================================================================

from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=BASE_DIR / ".env", extra="ignore")

    gemini_api_key: str = ""
    google_api_key: str = ""
    anthropic_api_key: str = ""
    ai_model: str = "gemini-3.5-flash"
    ai_timeout_seconds: float = 40.0

    jwt_secret: str = Field(min_length=32)
    jwt_expire_days: int = 7

    database_url: str = f"sqlite:///{(BASE_DIR / 'data' / 'bepviet.db').as_posix()}"
    cors_origin_regex: str = r"https?://(localhost|127\.0\.0\.1)(:\d+)?"

    @property
    def effective_gemini_key(self) -> str:
        return (self.gemini_api_key or self.google_api_key).strip()

    @property
    def effective_model(self) -> str:
        if self.effective_gemini_key:
            if not self.ai_model or self.ai_model.startswith("claude") or self.ai_model.startswith("gemini-2.5"):
                return "gemini-3.5-flash"
            return self.ai_model
        if not self.ai_model or self.ai_model.startswith("gemini"):
            return "claude-opus-5-5"
        return self.ai_model

    @property
    def ai_enabled(self) -> bool:
        return bool(self.effective_gemini_key or self.anthropic_api_key.strip())


@lru_cache
def get_settings() -> Settings:
    return Settings()
