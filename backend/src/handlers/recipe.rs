use axum::{
    extract::{Path, Query, State},
    Json,
};

use crate::error::AppError;
use crate::middleware::auth::MaybeAuthUser;
use crate::models::recipe::{
    IngredientSearchQuery, IngredientVocabularyItem, RecipeDetailDto, RecipeListQuery,
    RecipeScoreResult, RecipeStatsDto, RecipeSummaryDto, SearchQuery, SpoonacularCatalogItem,
    SuggestItemResponse, SuggestRequest,
};
use crate::services::recipe_service;
use crate::state::AppState;

pub async fn get_catalog(
    State(state): State<AppState>,
) -> Result<Json<Vec<SpoonacularCatalogItem>>, AppError> {
    let items = recipe_service::get_catalog(&state.pool).await?;
    Ok(Json(items))
}

pub async fn list_recipes(
    State(state): State<AppState>,
    maybe_user: MaybeAuthUser,
    Query(query): Query<RecipeListQuery>,
) -> Result<Json<Vec<RecipeSummaryDto>>, AppError> {
    let summaries = recipe_service::list_recipes(
        &state.pool,
        query.category.as_deref(),
        query.max_time,
        maybe_user.user_id(),
    )
    .await?;
    Ok(Json(summaries))
}

pub async fn get_recipe_by_id(
    State(state): State<AppState>,
    maybe_user: MaybeAuthUser,
    Path(id): Path<i64>,
) -> Result<Json<RecipeDetailDto>, AppError> {
    let detail = recipe_service::get_recipe_by_id(&state.pool, id, maybe_user.user_id()).await?;
    Ok(Json(detail))
}

pub async fn search_recipes(
    State(state): State<AppState>,
    maybe_user: MaybeAuthUser,
    Query(query): Query<SearchQuery>,
) -> Result<Json<Vec<RecipeSummaryDto>>, AppError> {
    let term = query.term.unwrap_or_default();
    let results =
        recipe_service::search_recipes(&state.pool, &term, maybe_user.user_id()).await?;
    Ok(Json(results))
}

pub async fn search_by_ingredients(
    State(state): State<AppState>,
    maybe_user: MaybeAuthUser,
    Query(query): Query<IngredientSearchQuery>,
) -> Result<Json<Vec<RecipeScoreResult>>, AppError> {
    let ingredients = query.ingredients.unwrap_or_default();
    let results = recipe_service::search_by_ingredients(
        &state.pool,
        &ingredients,
        maybe_user.user_id(),
    )
    .await?;
    Ok(Json(results))
}

pub async fn suggest(
    State(state): State<AppState>,
    Json(req): Json<SuggestRequest>,
) -> Result<Json<Vec<SuggestItemResponse>>, AppError> {
    let suggestions = recipe_service::suggest_recipes(&state.pool, &req).await?;
    Ok(Json(suggestions))
}

pub async fn get_ingredients(
    State(state): State<AppState>,
) -> Result<Json<Vec<IngredientVocabularyItem>>, AppError> {
    let items = recipe_service::get_ingredients_list(&state.pool).await?;
    Ok(Json(items))
}

pub async fn get_stats(
    State(state): State<AppState>,
) -> Result<Json<RecipeStatsDto>, AppError> {
    let stats = recipe_service::get_stats(&state.pool).await?;
    Ok(Json(stats))
}
