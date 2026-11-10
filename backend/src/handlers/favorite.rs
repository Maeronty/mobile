use axum::{
    extract::{Path, State},
    Json,
};

use crate::error::AppError;
use crate::middleware::auth::{AuthUser, MaybeAuthUser};
use crate::models::favorite::{
    SyncFavoritesPayload, SyncFavoritesResponse, ToggleFavoriteResponse,
};
use crate::models::recipe::RecipeSummaryDto;
use crate::services::favorite_service;
use crate::state::AppState;

pub async fn toggle_favorite(
    State(state): State<AppState>,
    auth_user: AuthUser,
    Path(recipe_id): Path<i64>,
) -> Result<Json<ToggleFavoriteResponse>, AppError> {
    let user_id = auth_user.user_id()?;
    let result = favorite_service::toggle_favorite(&state.pool, user_id, recipe_id).await?;
    Ok(Json(result))
}

pub async fn get_favorites(
    State(state): State<AppState>,
    maybe_user: MaybeAuthUser,
) -> Result<Json<Vec<RecipeSummaryDto>>, AppError> {
    let user_id = match maybe_user.user_id() {
        Some(uid) => uid,
        None => return Ok(Json(vec![])),
    };

    let items = favorite_service::get_user_favorites(&state.pool, user_id).await?;
    Ok(Json(items))
}

pub async fn sync_favorites(
    State(state): State<AppState>,
    auth_user: AuthUser,
    Json(payload): Json<SyncFavoritesPayload>,
) -> Result<Json<SyncFavoritesResponse>, AppError> {
    let user_id = auth_user.user_id()?;
    let recipe_ids = payload.into_recipe_ids();
    let result = favorite_service::sync_favorites(&state.pool, user_id, recipe_ids).await?;
    Ok(Json(result))
}
