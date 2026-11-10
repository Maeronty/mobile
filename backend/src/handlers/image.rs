//! =============================================================================
//! PROXY ẢNH MÓN ĂN — `GET /api/image?url=<link ảnh>`
//! =============================================================================
//!
//! VÌ SAO CẦN
//!   Flutter Web tải ảnh bằng XHR nên ảnh khác domain phải có header CORS.
//!   monngonmoingay.com và img.spoonacular.com KHÔNG gửi header này → trình
//!   duyệt chặn, app web không hiện ảnh. Route này tải ảnh hộ rồi trả về kèm
//!   CORS (lớp CorsLayer chung của app). App mobile/desktop vẫn tải thẳng.
//!
//! FLOW
//!   1. Chỉ nhận URL `https://` thuộc danh sách host cho phép → chặn việc dùng
//!      server để tải nội dung tuỳ ý (SSRF).
//!   2. Tải ảnh (timeout 20 giây), chỉ chấp nhận `Content-Type: image/*`,
//!      tối đa 5 MB.
//!   3. Trả ảnh với `Cache-Control: public, max-age=86400` để trình duyệt
//!      không tải lại mỗi lần cuộn.
//! =============================================================================

use axum::{
    body::Body,
    extract::{Query, State},
    http::{header, StatusCode},
    response::{IntoResponse, Response},
};
use serde::Deserialize;

use crate::{error::AppError, state::AppState};

const ALLOWED_HOSTS: &[&str] = &["monngonmoingay.com", "img.spoonacular.com", "spoonacular.com"];
const MAX_IMAGE_BYTES: usize = 5 * 1024 * 1024;

#[derive(Debug, Deserialize)]
pub struct ImageQuery {
    pub url: String,
}

/// Kiểm tra URL ảnh có được phép tải hộ không.
pub fn is_allowed_image_url(raw: &str) -> bool {
    let Ok(url) = reqwest::Url::parse(raw) else { return false };
    url.scheme() == "https"
        && url.port().is_none()
        && url.host_str().is_some_and(|h| {
            ALLOWED_HOSTS.iter().any(|a| h == *a || h.ends_with(&format!(".{a}")))
        })
}

pub async fn proxy_image(
    State(state): State<AppState>,
    Query(q): Query<ImageQuery>,
) -> Result<Response, AppError> {
    if !is_allowed_image_url(&q.url) {
        return Err(AppError::BadRequest("Nguồn ảnh không được hỗ trợ.".to_string()));
    }

    let upstream = state.http.get(&q.url).send().await.map_err(|e| {
        tracing::warn!("Không tải được ảnh {}: {e}", q.url);
        AppError::NotFound("Không tải được ảnh.".to_string())
    })?;
    if !upstream.status().is_success() {
        return Err(AppError::NotFound("Không tải được ảnh.".to_string()));
    }
    let content_type = upstream
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("")
        .to_string();
    if !content_type.starts_with("image/") {
        return Err(AppError::BadRequest("Đường dẫn không phải ảnh.".to_string()));
    }
    let bytes = upstream
        .bytes()
        .await
        .map_err(|_| AppError::NotFound("Không tải được ảnh.".to_string()))?;
    if bytes.len() > MAX_IMAGE_BYTES {
        return Err(AppError::BadRequest("Ảnh quá lớn.".to_string()));
    }

    Ok((
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, content_type),
            (header::CACHE_CONTROL, "public, max-age=86400".to_string()),
        ],
        Body::from(bytes),
    )
        .into_response())
}
