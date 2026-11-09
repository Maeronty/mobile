# =============================================================================
# FEATURE CÔNG THỨC: DỮ LIỆU TRẢ VỀ
# =============================================================================
#
# LƯU Ý
#   Tên trường khớp với `Recipe.fromJson` của app. `imageUrl` và `imageAsset`
#   cùng giá trị, vì app đọc `imageUrl` trước rồi mới đến `imageAsset`.
# =============================================================================

from app.core.schemas import ApiModel


class IngredientOut(ApiModel):
    name: str
    amount: float
    unit: str
    note: str | None = None


class InstructionOut(ApiModel):
    step_number: int
    description: str
    estimated_minutes: int | None = None
    tip: str | None = None


class NutritionOut(ApiModel):
    calories: int
    protein_grams: float
    carbs_grams: float
    fat_grams: float
    fiber_grams: float | None = None


class RecipeOut(ApiModel):
    id: int
    title: str
    description: str
    image_asset: str
    image_url: str
    category: str
    tags: list[str]
    cook_time_minutes: int
    difficulty: str
    servings: int
    calories: int
    average_rating: float
    total_ratings: int
    is_favorited: bool
    nutrition: NutritionOut
    ingredients: list[IngredientOut]
    instructions: list[InstructionOut]
    match_score: float | None = None
    matched_ingredients: list[str] = []
    missing_ingredients: list[str] = []


class FavoriteToggleOut(ApiModel):
    is_favorited: bool
