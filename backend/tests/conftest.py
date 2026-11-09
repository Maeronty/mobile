# Cấu hình test: dùng database tạm và không đọc API key thật trong `.env`.
# Biến môi trường phải đặt TRƯỚC khi import app, vì engine được tạo lúc import.

import os
import tempfile
from pathlib import Path

_TMP_DIR = tempfile.mkdtemp(prefix="bepviet_test_")
os.environ["DATABASE_URL"] = f"sqlite:///{(Path(_TMP_DIR) / 'test.db').as_posix()}"
os.environ["JWT_SECRET"] = "test-secret-" + "x" * 40
os.environ["ANTHROPIC_API_KEY"] = ""
os.environ["GEMINI_API_KEY"] = ""
os.environ["GOOGLE_API_KEY"] = ""

import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.core.database import Base, engine
from app.main import app


@pytest.fixture
def client():
    Base.metadata.drop_all(engine)
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def register(client):
    """Tạo tài khoản, trả về header đăng nhập của tài khoản đó."""

    def _register(username: str = "an_nguyen") -> dict:
        response = client.post(
            "/api/Account/register",
            json={"username": username, "email": f"{username}@example.com", "password": "matkhau123"},
        )
        assert response.status_code == 201, response.text
        return {"Authorization": f"Bearer {response.json()['token']}"}

    return _register


@pytest.fixture
def ai_settings(monkeypatch):
    """Bật AI trong test. Không gọi API thật: base URL trỏ về server giả."""
    settings = get_settings()
    monkeypatch.setattr(settings, "anthropic_api_key", "test-key")
    return settings
