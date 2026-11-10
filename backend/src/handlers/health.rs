use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use crate::state::AppState;

pub async fn health_check(State(state): State<AppState>) -> Response {
    match sqlx::query("SELECT 1").execute(&state.pool).await {
        Ok(_) => (
            StatusCode::OK,
            Json(json!({
                "status": "ok",
                "database": "connected"
            })),
        )
            .into_response(),
        Err(err) => {
            tracing::error!("Health check database ping failed: {:?}", err);
            (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(json!({
                    "status": "error",
                    "database": "disconnected"
                })),
            )
                .into_response()
        }
    }
}
