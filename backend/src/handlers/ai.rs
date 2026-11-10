//! Route AI: chỉ nhận request và gọi `AiService`. Logic nằm trong
//! `services/ai_service.rs`.
//!
//! Bắt buộc đăng nhập (`AuthUser`): mỗi request tốn lượt gọi Gemini/Spoonacular,
//! nên khách không được dùng để người lạ không dùng hết hạn mức của key.

use axum::{extract::State, Json};

use crate::{
    error::AppError,
    middleware::AuthUser,
    models::{AiSuggestItem, AiSuggestRequest, RecognizeRequest},
    state::AppState,
};

pub async fn recognize(
    State(state): State<AppState>,
    _user: AuthUser,
    Json(req): Json<RecognizeRequest>,
) -> Result<Json<Vec<String>>, AppError> {
    Ok(Json(state.ai.recognize(&req).await?))
}

pub async fn suggest(
    State(state): State<AppState>,
    _user: AuthUser,
    Json(req): Json<AiSuggestRequest>,
) -> Result<Json<Vec<AiSuggestItem>>, AppError> {
    Ok(Json(state.ai.suggest(&req).await?))
}
