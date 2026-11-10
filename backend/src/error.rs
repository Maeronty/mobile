use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("Yêu cầu không hợp lệ: {0}")]
    BadRequest(String),

    #[error("Chưa xác thực hoặc token không hợp lệ: {0}")]
    Unauthorized(String),

    #[error("Không có quyền truy cập: {0}")]
    Forbidden(String),

    #[error("Không tìm thấy tài nguyên: {0}")]
    NotFound(String),

    #[error("Dữ liệu xung đột: {0}")]
    Conflict(String),

    #[error("Lỗi cơ sở dữ liệu: {0}")]
    Database(#[from] sqlx::Error),

    #[error("Lỗi hệ thống nội bộ: {0}")]
    Internal(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            AppError::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg),
            AppError::Unauthorized(msg) => (StatusCode::UNAUTHORIZED, msg),
            AppError::Forbidden(msg) => (StatusCode::FORBIDDEN, msg),
            AppError::NotFound(msg) => (StatusCode::NOT_FOUND, msg),
            AppError::Conflict(msg) => (StatusCode::CONFLICT, msg),
            AppError::Database(err) => {
                tracing::error!("Database error: {:?}", err);
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("Lỗi cơ sở dữ liệu nội bộ: {}", err),
                )
            }
            AppError::Internal(msg) => {
                tracing::error!("Internal error: {}", msg);
                (StatusCode::INTERNAL_SERVER_ERROR, msg)
            }
        };

        let body = Json(json!({
            "success": false,
            "message": message,
            "error": message
        }));

        (status, body).into_response()
    }
}
