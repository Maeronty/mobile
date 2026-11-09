# Route công thức: chỉ nhận request và gọi service. Logic nằm trong `service.py`.
# Các route có đường dẫn cố định phải đặt trước `/{recipe_id}`.

from fastapi import APIRouter

from app.core.deps import CurrentUser, Db, OptionalUser
from app.features.recipes import service
from app.features.recipes.schemas import FavoriteToggleOut, RecipeOut

router = APIRouter(prefix="/Recipes", tags=["Công thức"])


@router.get("", response_model=list[RecipeOut])
def list_recipes(db: Db, user: OptionalUser):
    return service.list_recipes(db, user)


@router.get("/search", response_model=list[RecipeOut])
def search(db: Db, user: OptionalUser, term: str = ""):
    return service.search_by_name(db, term, user)


@router.get("/search-by-ingredients", response_model=list[RecipeOut])
def search_by_ingredients(ingredients: str, db: Db, user: OptionalUser):
    return service.search_by_ingredients(db, service.split_ingredients(ingredients), user)


@router.get("/favorites", response_model=list[int])
def favorites(db: Db, user: CurrentUser):
    return service.list_favorite_ids(db, user)


@router.get("/ingredients", response_model=list[str])
def ingredients(db: Db):
    return service.list_ingredient_names(db)


@router.get("/{recipe_id}", response_model=RecipeOut)
def get_recipe(recipe_id: int, db: Db, user: OptionalUser):
    return service.get_recipe(db, recipe_id, user)


@router.post("/{recipe_id}/favorite", response_model=FavoriteToggleOut)
def toggle_favorite(recipe_id: int, db: Db, user: CurrentUser):
    return FavoriteToggleOut(is_favorited=service.toggle_favorite(db, recipe_id, user))
