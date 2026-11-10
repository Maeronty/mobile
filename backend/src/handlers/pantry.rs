use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json,
};

use crate::error::AppError;
use crate::middleware::auth::AuthUser;
use crate::models::pantry::{
    AddPantryResponse, CreatePantryPayload, DeletePantryQuery, PantryListResponse,
    UpdatePantryItemRequest, UpdatePantryResponse,
};
use crate::models::recipe::RecipeScoreResult;
use crate::services::{pantry_service, recipe_service};
use crate::state::AppState;

/// GET /api/pantry (and /api/kitchen-bag)
pub async fn get_pantry(
    State(state): State<AppState>,
    auth_user: AuthUser,
) -> Result<Json<PantryListResponse>, AppError> {
    let user_id = auth_user.user_id()?;
    let list = pantry_service::get_pantry(&state.pool, user_id).await?;
    Ok(Json(list))
}

/// POST /api/pantry (and /api/kitchen-bag)
pub async fn add_pantry_item(
    State(state): State<AppState>,
    auth_user: AuthUser,
    Json(payload): Json<CreatePantryPayload>,
) -> Result<(StatusCode, Json<AddPantryResponse>), AppError> {
    let user_id = auth_user.user_id()?;
    let res = pantry_service::add_pantry_payload(&state.pool, user_id, payload).await?;
    Ok((StatusCode::CREATED, Json(res)))
}

/// PUT /api/pantry/:id (and /api/kitchen-bag/:id)
pub async fn update_pantry_item(
    State(state): State<AppState>,
    auth_user: AuthUser,
    Path(id): Path<i64>,
    Json(req): Json<UpdatePantryItemRequest>,
) -> Result<Json<UpdatePantryResponse>, AppError> {
    let user_id = auth_user.user_id()?;
    let item = pantry_service::update_pantry_item(&state.pool, user_id, id, req).await?;
    Ok(Json(UpdatePantryResponse {
        message: "Cập nhật nguyên liệu thành công.".to_string(),
        item,
    }))
}

/// DELETE /api/pantry/:id (and /api/kitchen-bag/:id)
pub async fn delete_pantry_item_by_id(
    State(state): State<AppState>,
    auth_user: AuthUser,
    Path(id): Path<i64>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = auth_user.user_id()?;
    pantry_service::delete_pantry_item(&state.pool, user_id, id).await?;
    Ok(Json(serde_json::json!({
        "message": "Đã xóa nguyên liệu khỏi tủ lạnh."
    })))
}

/// DELETE /api/pantry (and /api/kitchen-bag) - supports ?name=... or clears all if omitted
pub async fn delete_or_clear_pantry(
    State(state): State<AppState>,
    auth_user: AuthUser,
    query: Option<Query<DeletePantryQuery>>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = auth_user.user_id()?;
    let name_param = query
        .and_then(|q| q.0.name)
        .map(|n| n.trim().to_string())
        .filter(|n| !n.is_empty());

    if let Some(name) = name_param {
        pantry_service::delete_pantry_by_name(&state.pool, user_id, &name).await?;
        Ok(Json(serde_json::json!({
            "message": "Đã xóa nguyên liệu khỏi tủ lạnh."
        })))
    } else {
        let deleted_count = pantry_service::clear_pantry(&state.pool, user_id).await?;
        Ok(Json(serde_json::json!({
            "message": "Đã dọn sạch toàn bộ tủ lạnh.",
            "deletedCount": deleted_count
        })))
    }
}

/// GET /api/pantry/suggest (and /api/kitchen-bag/suggest)
pub async fn suggest_from_pantry(
    State(state): State<AppState>,
    auth_user: AuthUser,
) -> Result<Json<Vec<RecipeScoreResult>>, AppError> {
    let user_id = auth_user.user_id()?;
    let pantry = pantry_service::get_pantry(&state.pool, user_id).await?;
    if pantry.ingredient_names.is_empty() {
        return Ok(Json(vec![]));
    }
    let ingredients_csv = pantry.ingredient_names.join(",");
    let suggestions = recipe_service::search_by_ingredients(
        &state.pool,
        &ingredients_csv,
        Some(user_id),
    )
    .await?;
    Ok(Json(suggestions))
}
