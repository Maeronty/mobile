import pytest
from unittest.mock import MagicMock, patch
from google.genai import errors

from app.core.config import get_settings
from app.features.nutrition.ai_client import AiUnavailable, _generate_gemini_plan, generate_ai_plan
from app.features.nutrition.schemas import AiDay, AiMeal, AiMealPlan, GeneratePlanIn
from app.core.models import Recipe


def _sample_plan(days: int = 2) -> AiMealPlan:
    return AiMealPlan(
        overview="Lời khuyên dinh dưỡng từ Gemini",
        days=[
            AiDay(
                nutrition_summary=f"Dinh dưỡng ngày {d + 1}",
                meals=[
                    AiMeal(
                        meal_type="Bữa sáng",
                        dish_name="Phở Bò",
                        recipe_id=1,
                        calories=500,
                        protein_grams=30.0,
                        carbs_grams=60.0,
                        fat_grams=12.0,
                        tip="Ăn nóng",
                    ),
                    AiMeal(
                        meal_type="Bữa trưa",
                        dish_name="Cơm Tấm",
                        recipe_id=4,
                        calories=650,
                        protein_grams=35.0,
                        carbs_grams=70.0,
                        fat_grams=20.0,
                        tip="Ít mỡ hành",
                    ),
                    AiMeal(
                        meal_type="Bữa tối",
                        dish_name="Cá Hồi Áp Chảo",
                        recipe_id=8,
                        calories=480,
                        protein_grams=36.0,
                        carbs_grams=10.0,
                        fat_grams=30.0,
                        tip="Ăn kèm măng tây",
                    ),
                ],
            )
            for d in range(days)
        ],
    )


def test_gemini_settings_properties(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "gemini_api_key", "test-gemini-key")
    monkeypatch.setattr(settings, "google_api_key", "")
    monkeypatch.setattr(settings, "ai_model", "gemini-3.5-flash")

    assert settings.ai_enabled is True
    assert settings.effective_gemini_key == "test-gemini-key"
    assert settings.effective_model == "gemini-3.5-flash"


def test_google_api_key_fallback(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "gemini_api_key", "")
    monkeypatch.setattr(settings, "google_api_key", "test-google-key")
    monkeypatch.setattr(settings, "ai_model", "")

    assert settings.ai_enabled is True
    assert settings.effective_gemini_key == "test-google-key"
    assert settings.effective_model == "gemini-3.5-flash"


def test_generate_gemini_plan_success(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "gemini_api_key", "test-gemini-key")

    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.candidates = [MagicMock(finish_reason="STOP")]
    mock_response.parsed = _sample_plan(2)
    mock_client.models.generate_content.return_value = mock_response

    with patch("google.genai.Client", return_value=mock_client):
        plan_in = GeneratePlanIn(days=2)
        recipes = [Recipe(id=1, title="Phở", category="Món Việt", tags=[], calories=500, protein_grams=30, carbs_grams=60, fat_grams=12, ingredients=[])]
        result = _generate_gemini_plan(plan_in, recipes)
        assert result.overview == "Lời khuyên dinh dưỡng từ Gemini"
        assert len(result.days) == 2


def test_gemini_api_key_invalid(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "gemini_api_key", "invalid-key")

    mock_client = MagicMock()
    err = errors.APIError(code=400, response_json={"error": "API_KEY_INVALID"})
    mock_client.models.generate_content.side_effect = err

    with patch("google.genai.Client", return_value=mock_client):
        plan_in = GeneratePlanIn(days=2)
        with pytest.raises(AiUnavailable, match="API key của AI không hợp lệ"):
            _generate_gemini_plan(plan_in, [])


def test_gemini_rate_limited(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "gemini_api_key", "test-key")

    mock_client = MagicMock()
    err = errors.APIError(code=429, response_json={"error": "RESOURCE_EXHAUSTED"})
    mock_client.models.generate_content.side_effect = err

    with patch("google.genai.Client", return_value=mock_client):
        plan_in = GeneratePlanIn(days=2)
        with pytest.raises(AiUnavailable, match="AI đang quá tải"):
            _generate_gemini_plan(plan_in, [])


def test_gemini_safety_block(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "gemini_api_key", "test-key")

    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.candidates = [MagicMock(finish_reason="SAFETY")]
    mock_client.models.generate_content.return_value = mock_response

    with patch("google.genai.Client", return_value=mock_client):
        plan_in = GeneratePlanIn(days=2)
        with pytest.raises(AiUnavailable, match="AI không thể xử lý yêu cầu này"):
            _generate_gemini_plan(plan_in, [])


def test_gemini_dispatches_when_key_set(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "gemini_api_key", "test-gemini-key")
    monkeypatch.setattr(settings, "anthropic_api_key", "")

    with patch("app.features.nutrition.ai_client._generate_gemini_plan") as mock_gemini:
        mock_gemini.return_value = _sample_plan(2)
        plan_in = GeneratePlanIn(days=2)
        plan = generate_ai_plan(plan_in, [])
        assert mock_gemini.called
        assert len(plan.days) == 2

