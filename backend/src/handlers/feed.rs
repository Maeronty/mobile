//! Route danh sách món có phân trang: chỉ nhận request và gọi `feed_service`.

use axum::{
    extract::{Query, State},
    Json,
};

use crate::{
    error::AppError,
    models::{CategoryCountDto, PageQuery, RecipeCardDto, RecipePageDto},
    services::feed_service,
    state::AppState,
};

/// `GET /api/Recipes/page?page=1&pageSize=20&category=Canh&q=phở`
pub async fn page(
    State(state): State<AppState>,
    Query(q): Query<PageQuery>,
) -> Result<Json<RecipePageDto>, AppError> {
    Ok(Json(feed_service::page_recipes(&state.pool, &q).await?))
}

/// `GET /api/Recipes/categories`
pub async fn categories(State(state): State<AppState>) -> Result<Json<Vec<CategoryCountDto>>, AppError> {
    Ok(Json(feed_service::categories(&state.pool).await?))
}

/// `GET /api/Recipes/featured`
pub async fn featured(State(state): State<AppState>) -> Result<Json<Vec<RecipeCardDto>>, AppError> {
    Ok(Json(feed_service::featured(&state.pool).await?))
}
