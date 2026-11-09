# =============================================================================
# FEATURE: THỰC ĐƠN DINH DƯỠNG
# =============================================================================
#
# FLOW
#   1. App gửi đối tượng, mục tiêu, số ngày, nguyên liệu đang có.
#   2. Đã có API key VÀ người dùng đã đăng nhập → gọi AI.
#   3. AI lỗi, hoặc không đủ điều kiện gọi AI → tạo thực đơn theo quy tắc.
#      Trường `source` cho biết kết quả từ đâu; `notice` ghi lý do nếu AI lỗi.
#
# CÁCH TẠO THEO QUY TẮC
#   1. Bỏ món tráng miệng khỏi bữa chính.
#   2. Xếp hạng: món dùng được nhiều nguyên liệu đang có lên trước, sau đó theo
#      mục tiêu (Giảm cân: ít calo; Tăng cơ: nhiều đạm; Eat Clean: món Healthy trước).
#   3. Xếp lần lượt vào sáng / trưa / tối, hết danh sách thì quay vòng.
#
# LƯU Ý
#   - Khách không được gọi AI để người lạ không dùng hết tiền của API key.
#   - Dữ liệu mẫu chưa có món chay, nên thực đơn chay chỉ làm được khi dùng AI:
#     nếu không có AI, BE báo lỗi 503 thay vì trả thực đơn có thịt.
# =============================================================================

import logging

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.models import Recipe, User
from app.core.text import normalize_text
from app.features.nutrition.ai_client import AiUnavailable, generate_ai_plan
from app.features.nutrition.schemas import AiMealPlan, DayOut, GeneratePlanIn, MealOut, MealPlanOut
from app.features.recipes.service import is_ingredient_match, load_all_recipes

logger = logging.getLogger(__name__)

_DAY_NAMES = ["Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật"]
_MAIN_MEALS = ["Bữa sáng", "Bữa trưa", "Bữa tối"]
_DEFAULT_IMAGE = "assets/images/pho.png"
_DESSERT_CATEGORY = "Tráng miệng"

_GOAL_ADVICE = {
    "Giảm cân": "Thực đơn ưu tiên món ít calo. Hãy uống đủ nước và ăn chậm để no lâu hơn.",
    "Tăng cơ": "Thực đơn ưu tiên món giàu đạm. Nên ăn đủ bữa và kết hợp tập luyện đều đặn.",
    "Eat Clean": "Thực đơn ưu tiên món thanh đạm, nhiều rau xanh và ít dầu mỡ.",
}
_DEFAULT_ADVICE = "Thực đơn cân bằng giữa đạm, tinh bột và chất béo, với nhiều món đa dạng trong tuần."


def _goal_rank(recipe: Recipe, goal: str) -> tuple:
    if goal == "Giảm cân":
        return (recipe.calories,)
    if goal == "Tăng cơ":
        return (-recipe.protein_grams,)
    if goal == "Eat Clean":
        is_clean = recipe.category == "Healthy" or "Eat Clean" in recipe.tags
        return (not is_clean, recipe.calories)
    return (-recipe.average_rating,)


def _meal_from_recipe(recipe: Recipe, meal_type: str) -> MealOut:
    tip = next((step.tip for step in recipe.instructions if step.tip), "")
    return MealOut(
        meal_type=meal_type,
        dish_name=recipe.title,
        image_asset=recipe.image_asset,
        calories=recipe.calories,
        protein_grams=recipe.protein_grams,
        carbs_grams=recipe.carbs_grams,
        fat_grams=recipe.fat_grams,
        tip=tip,
    )


def _build_day(day_index: int, meals: list[MealOut], summary: str | None) -> DayOut:
    protein = sum(m.protein_grams for m in meals)
    carbs = sum(m.carbs_grams for m in meals)
    fat = sum(m.fat_grams for m in meals)
    return DayOut(
        day_number=day_index + 1,
        day_name=_DAY_NAMES[day_index],
        meals=meals,
        total_calories=sum(m.calories for m in meals),
        nutrition_summary=summary or f"Đạm {protein:.0f}g · Tinh bột {carbs:.0f}g · Chất béo {fat:.0f}g",
    )


def _rule_based_plan(data: GeneratePlanIn, recipes: list[Recipe], notice: str | None) -> MealPlanOut:
    if data.is_vegetarian:
        message = "Thực đơn chay cần AI, nhưng AI hiện không dùng được"
        if notice is None and not get_settings().ai_enabled:
            message = "Thực đơn chay cần cấu hình API key cho AI trên server"
        elif notice is None:
            message = "Thực đơn chay bằng AI cần đăng nhập"
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, message)

    inputs = [normalize_text(i) for i in data.ingredients]

    def match_count(recipe: Recipe) -> int:
        return sum(is_ingredient_match(i.name, inputs) for i in recipe.ingredients)

    pool = sorted(
        (r for r in recipes if r.category != _DESSERT_CATEGORY),
        key=lambda r: (-match_count(r), *_goal_rank(r, data.health_goal), r.id),
    )
    if not pool:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Chưa có công thức nào để tạo thực đơn")

    days = []
    for day_index in range(data.days):
        meals = [
            _meal_from_recipe(pool[(day_index * len(_MAIN_MEALS) + slot) % len(pool)], meal_type)
            for slot, meal_type in enumerate(_MAIN_MEALS)
        ]
        days.append(_build_day(day_index, meals, None))

    return MealPlanOut(
        target_group=data.target_group,
        health_goal=data.health_goal,
        total_days=data.days,
        advisor_advice=_GOAL_ADVICE.get(data.health_goal, _DEFAULT_ADVICE),
        daily_plans=days,
        source="rule_based",
        notice=notice,
    )


def _plan_from_ai(data: GeneratePlanIn, ai_plan: AiMealPlan, recipes: list[Recipe]) -> MealPlanOut:
    images = {r.id: r.image_asset for r in recipes}
    days = [
        _build_day(
            day_index,
            [
                MealOut(
                    meal_type=meal.meal_type,
                    dish_name=meal.dish_name,
                    # recipe_id do AI trả về có thể không tồn tại → dùng ảnh mặc định.
                    image_asset=images.get(meal.recipe_id, _DEFAULT_IMAGE),
                    calories=meal.calories,
                    protein_grams=meal.protein_grams,
                    carbs_grams=meal.carbs_grams,
                    fat_grams=meal.fat_grams,
                    tip=meal.tip,
                )
                for meal in day.meals
            ],
            day.nutrition_summary,
        )
        for day_index, day in enumerate(ai_plan.days)
    ]
    return MealPlanOut(
        target_group=data.target_group,
        health_goal=data.health_goal,
        total_days=data.days,
        advisor_advice=ai_plan.overview,
        daily_plans=days,
        source="ai",
    )


def generate_plan(db: Session, data: GeneratePlanIn, user: User | None) -> MealPlanOut:
    recipes = load_all_recipes(db)

    if not get_settings().ai_enabled or user is None:
        return _rule_based_plan(data, recipes, None)

    try:
        return _plan_from_ai(data, generate_ai_plan(data, recipes), recipes)
    except AiUnavailable as exc:
        return _rule_based_plan(data, recipes, f"{exc} nên thực đơn được tạo từ công thức có sẵn.")
