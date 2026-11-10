use axum::{
    async_trait,
    extract::FromRequestParts,
    http::{header::AUTHORIZATION, request::Parts, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;

use crate::error::AppError;
use crate::services::auth_service::{verify_jwt, Claims};
use crate::state::AppState;

#[derive(Debug, Clone)]
pub struct AuthUser(pub Claims);

impl AuthUser {
    pub fn user_id(&self) -> Result<i64, AppError> {
        self.0
            .sub
            .parse::<i64>()
            .map_err(|_| AppError::Unauthorized("ID người dùng không hợp lệ.".to_string()))
    }
}

#[async_trait]
impl FromRequestParts<AppState> for AuthUser {
    type Rejection = Response;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let unauthorized = || {
            (
                StatusCode::UNAUTHORIZED,
                Json(json!({
                    "message": "Vui lòng đăng nhập để tiếp tục.",
                    "error": "Unauthorized"
                })),
            )
                .into_response()
        };

        let auth_header = parts
            .headers
            .get(AUTHORIZATION)
            .and_then(|val| val.to_str().ok());

        let token = match auth_header {
            Some(header) if header.starts_with("Bearer ") => &header[7..],
            _ => return Err(unauthorized()),
        };

        let secret = &state.config.jwt_secret;

        match verify_jwt(token, secret) {
            Ok(claims) => Ok(AuthUser(claims)),
            Err(_) => Err(unauthorized()),
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct MaybeAuthUser(pub Option<Claims>);

impl MaybeAuthUser {
    pub fn user_id(&self) -> Option<i64> {
        self.0.as_ref().and_then(|c| c.sub.parse::<i64>().ok())
    }
}

#[async_trait]
impl FromRequestParts<AppState> for MaybeAuthUser {
    type Rejection = std::convert::Infallible;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get(AUTHORIZATION)
            .and_then(|val| val.to_str().ok());

        let token = match auth_header {
            Some(header) if header.starts_with("Bearer ") => &header[7..],
            _ => return Ok(MaybeAuthUser(None)),
        };

        let secret = &state.config.jwt_secret;

        match verify_jwt(token, secret) {
            Ok(claims) => Ok(MaybeAuthUser(Some(claims))),
            Err(_) => Ok(MaybeAuthUser(None)),
        }
    }
}
