//! Dữ liệu vào/ra của tính năng AI (`/api/Ai/*`).
//!
//! Giữ đúng dạng JSON mà server Node `server/food.mjs` (nhánh của sionby) đã dùng,
//! để app Flutter không phải đổi cách đọc kết quả:
//!   - recognize: `{mime, data}` → `["Cà chua", ...]`
//!   - suggest:   `{ingredients}` → `[{id, title, reason, used, missing}]`

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize)]
pub struct RecognizeRequest {
    /// `image/jpeg`, `image/png` hoặc `image/webp`.
    pub mime: String,
    /// Nội dung ảnh mã hoá base64 (không có tiền tố `data:`).
    pub data: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AiSuggestRequest {
    pub ingredients: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AiSuggestItem {
    /// Id món trên Spoonacular.
    pub id: i64,
    pub title: String,
    pub reason: String,
    pub used: Vec<String>,
    pub missing: Vec<String>,
}
