//! Dữ liệu vào/ra của API danh sách món có phân trang (`/api/Recipes/page`,
//! `/api/Recipes/categories`, `/api/Recipes/featured`).
//!
//! `RecipeCardDto` chỉ có những trường cần để vẽ thẻ món (không có nguyên liệu,
//! các bước) → mỗi trang 20 món chỉ vài KB thay vì tải cả danh mục 3,4 MB.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct PageQuery {
    /// Bắt đầu từ 1. Thiếu hoặc < 1 → 1.
    pub page: Option<i64>,
    /// 1–50, mặc định 20.
    pub page_size: Option<i64>,
    /// Lọc đúng tên danh mục; bỏ trống = tất cả.
    pub category: Option<String>,
    /// Tìm theo tên món (không phân biệt hoa thường, có dấu).
    pub q: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct RecipeCardDto {
    pub id: i64,
    pub title: String,
    pub image: String,
    pub category: String,
    pub source: String,
    /// 0 = không rõ.
    pub cook_time_minutes: i64,
    /// true = thời gian nấu là ước lượng (app hiện "~").
    pub cook_time_estimated: bool,
    /// 0 = chưa có dữ liệu dinh dưỡng.
    pub calories: i64,
    /// true = calo ước tính từ nguyên liệu cho cả món (app hiện "~").
    pub calories_estimated: bool,
    pub ingredient_count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RecipePageDto {
    pub items: Vec<RecipeCardDto>,
    pub page: i64,
    pub page_size: i64,
    pub total: i64,
    pub has_more: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CategoryCountDto {
    pub name: String,
    pub count: i64,
}
