# =============================================================================
# FEATURE THỰC ĐƠN: DỮ LIỆU VÀO / RA
# =============================================================================
#
# GỒM 3 NHÓM
#   GeneratePlanIn : request từ app (khớp `NutritionService.generateMealPlan`).
#   AiMealPlan     : dạng JSON bắt AI phải trả về.
#   MealPlanOut    : response cho app (khớp `MealPlan.fromJson`).
#
# LƯU Ý
#   `AiMealPlan` không có ảnh hay tổng calo: BE tự tính từ dữ liệu của mình, nên
#   AI không thể trả về đường dẫn ảnh giả hoặc tổng số sai.
# =============================================================================

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

from app.core.schemas import ApiModel

IngredientName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
MealType = Literal["Bữa sáng", "Bữa trưa", "Bữa tối", "Bữa phụ"]


class GeneratePlanIn(ApiModel):
    ingredients: Annotated[list[IngredientName], Field(max_length=50)] = []
    target_group: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=50)] = "Cá nhân"
    health_goal: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=50)] = "Cân bằng"
    days: Annotated[int, Field(ge=1, le=7)] = 7
    meal_format: Annotated[str, StringConstraints(max_length=30)] = "family_tray"
    is_vegetarian: bool = False


class AiMeal(BaseModel):
    model_config = ConfigDict(extra="forbid")

    meal_type: MealType
    dish_name: str
    recipe_id: int | None
    calories: int
    protein_grams: float
    carbs_grams: float
    fat_grams: float
    tip: str


class AiDay(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nutrition_summary: str
    meals: list[AiMeal]


class AiMealPlan(BaseModel):
    model_config = ConfigDict(extra="forbid")

    overview: str
    days: list[AiDay]


class MealOut(ApiModel):
    meal_type: str
    dish_name: str
    image_asset: str
    calories: int
    protein_grams: float
    carbs_grams: float
    fat_grams: float
    tip: str


class DayOut(ApiModel):
    day_number: int
    day_name: str
    meals: list[MealOut]
    total_calories: int
    nutrition_summary: str


class MealPlanOut(ApiModel):
    target_group: str
    health_goal: str
    total_days: int
    advisor_advice: str
    daily_plans: list[DayOut]
    # "ai": do AI tạo; "rule_based": tạo theo quy tắc từ công thức có sẵn.
    source: Literal["ai", "rule_based"]
    # Lý do không dùng AI, để hiển thị cho người dùng. None nếu dùng AI hoặc khi
    # BE chưa cấu hình key.
    notice: str | None = None
