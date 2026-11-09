# =============================================================================
# FEATURE: CÔNG THỨC (danh sách, tìm kiếm, gợi ý theo nguyên liệu, yêu thích)
# =============================================================================
#
# THUẬT TOÁN GỢI Ý THEO NGUYÊN LIỆU (giống `suggest_controller.dart` của app)
#   Với mỗi công thức:
#     1. Một nguyên liệu tính là "đã có" nếu tên của nó CHỨA hoặc ĐƯỢC CHỨA trong
#        một nguyên liệu người dùng nhập. VD: "bò" khớp "Thịt bò thăn".
#     2. score = số nguyên liệu đã có / tổng số nguyên liệu (0.0 → 1.0).
#     3. Chỉ giữ món có ít nhất 1 nguyên liệu khớp.
#   Kết quả xếp theo điểm giảm dần.
#
# FLOW YÊU THÍCH
#   Bấm trái tim → có bản ghi thì xoá, chưa có thì thêm → trả về trạng thái mới.
#   `isFavorited` tính riêng theo từng người; khách luôn nhận `false`.
#
# LƯU Ý
#   Khác app: danh sách nguyên liệu rỗng trả về danh sách rỗng thay vì toàn bộ món,
#   đúng với `RecipeService.searchByIngredients` phía client.
# =============================================================================

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.models import Favorite, Ingredient, Recipe, User
from app.core.text import normalize_text
from app.features.recipes.schemas import IngredientOut, InstructionOut, NutritionOut, RecipeOut


def load_all_recipes(db: Session) -> list[Recipe]:
    query = (
        select(Recipe)
        .options(selectinload(Recipe.ingredients), selectinload(Recipe.instructions))
        .order_by(Recipe.id)
    )
    return list(db.scalars(query))


def _favorite_ids(db: Session, user: User | None) -> set[int]:
    if user is None:
        return set()
    return set(db.scalars(select(Favorite.recipe_id).where(Favorite.user_id == user.id)))


def _to_out(
    recipe: Recipe,
    favorite_ids: set[int],
    match_score: float | None = None,
    matched: list[str] | None = None,
    missing: list[str] | None = None,
) -> RecipeOut:
    return RecipeOut(
        id=recipe.id,
        title=recipe.title,
        description=recipe.description,
        image_asset=recipe.image_asset,
        image_url=recipe.image_asset,
        category=recipe.category,
        tags=recipe.tags,
        cook_time_minutes=recipe.cook_time_minutes,
        difficulty=recipe.difficulty,
        servings=recipe.servings,
        calories=recipe.calories,
        average_rating=recipe.average_rating,
        total_ratings=recipe.total_ratings,
        is_favorited=recipe.id in favorite_ids,
        nutrition=NutritionOut(
            calories=recipe.calories,
            protein_grams=recipe.protein_grams,
            carbs_grams=recipe.carbs_grams,
            fat_grams=recipe.fat_grams,
            fiber_grams=recipe.fiber_grams,
        ),
        ingredients=[IngredientOut.model_validate(i) for i in recipe.ingredients],
        instructions=[InstructionOut.model_validate(s) for s in recipe.instructions],
        match_score=match_score,
        matched_ingredients=matched or [],
        missing_ingredients=missing or [],
    )


def list_recipes(db: Session, user: User | None) -> list[RecipeOut]:
    favorite_ids = _favorite_ids(db, user)
    return [_to_out(r, favorite_ids) for r in load_all_recipes(db)]


def get_recipe(db: Session, recipe_id: int, user: User | None) -> RecipeOut:
    recipe = db.get(Recipe, recipe_id)
    if recipe is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Không tìm thấy công thức #{recipe_id}")
    return _to_out(recipe, _favorite_ids(db, user))


def search_by_name(db: Session, term: str, user: User | None) -> list[RecipeOut]:
    query = normalize_text(term)
    favorite_ids = _favorite_ids(db, user)
    return [
        _to_out(r, favorite_ids)
        for r in load_all_recipes(db)
        if not query
        or query in normalize_text(r.title)
        or query in normalize_text(r.category)
        or any(query in normalize_text(tag) for tag in r.tags)
    ]


def split_ingredients(raw: str) -> list[str]:
    return [part.strip() for part in raw.split(",") if part.strip()]


def is_ingredient_match(recipe_ingredient: str, user_ingredients: list[str]) -> bool:
    name = normalize_text(recipe_ingredient)
    return any(name in given or given in name for given in user_ingredients)


def search_by_ingredients(db: Session, ingredients: list[str], user: User | None) -> list[RecipeOut]:
    inputs = [normalize_text(i) for i in ingredients if normalize_text(i)]
    if not inputs:
        return []

    favorite_ids = _favorite_ids(db, user)
    scored: list[RecipeOut] = []
    for recipe in load_all_recipes(db):
        matched: list[str] = []
        missing: list[str] = []
        for ingredient in recipe.ingredients:
            (matched if is_ingredient_match(ingredient.name, inputs) else missing).append(ingredient.name)
        if matched:
            score = len(matched) / len(recipe.ingredients)
            scored.append(_to_out(recipe, favorite_ids, score, matched, missing))

    scored.sort(key=lambda r: r.match_score or 0, reverse=True)
    return scored


def toggle_favorite(db: Session, recipe_id: int, user: User) -> bool:
    if db.get(Recipe, recipe_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Không tìm thấy công thức #{recipe_id}")

    existing = db.get(Favorite, (user.id, recipe_id))
    if existing is not None:
        db.delete(existing)
        db.commit()
        return False

    db.add(Favorite(user_id=user.id, recipe_id=recipe_id))
    db.commit()
    return True


def list_favorite_ids(db: Session, user: User) -> list[int]:
    return sorted(_favorite_ids(db, user))


def list_ingredient_names(db: Session) -> list[str]:
    return list(db.scalars(select(Ingredient.name).distinct().order_by(Ingredient.name)))
