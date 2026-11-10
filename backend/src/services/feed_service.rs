//! =============================================================================
//! SERVICE: DANH SÁCH MÓN CÓ PHÂN TRANG (Home, danh mục)
//! =============================================================================
//!
//! FLOW `page_recipes`
//!   1. Chuẩn hoá tham số: page ≥ 1, pageSize 1–50 (mặc định 20).
//!   2. Lọc theo danh mục (so khớp chính xác) và/hoặc tên món (`q`).
//!   3. Đếm tổng số món khớp → tính `hasMore`.
//!   4. Lấy đúng 1 trang bằng LIMIT/OFFSET, kèm số nguyên liệu và calo
//!      (LEFT JOIN — món không có dinh dưỡng trả calories = 0).
//!   Thứ tự: món Việt (id ≥ 1.000.000) trước, rồi theo id → ổn định giữa các
//!   trang, không lặp/sót món khi cuộn.
//!
//! TÌM KIẾM `q`
//!   LIKE của SQLite chỉ bỏ qua hoa/thường với chữ ASCII ("Phở" ≠ "phở").
//!   Vì vậy so khớp trên `lower()` của Rust: tải id + tên (nhẹ), lọc trong bộ
//!   nhớ, rồi mới lấy trang. Với vài nghìn món việc này mất < 5 ms.
//!
//! `categories`: danh mục + số món, nhiều món trước, "Món khác" cuối.
//! `featured`: mỗi danh mục tiêu biểu 1 món Việt có ảnh, cho banner Home.
//! =============================================================================

use sqlx::SqlitePool;

use crate::error::AppError;
use crate::models::{CategoryCountDto, PageQuery, RecipeCardDto, RecipePageDto};

pub const DEFAULT_PAGE_SIZE: i64 = 20;
pub const MAX_PAGE_SIZE: i64 = 50;
const OTHER_CATEGORY: &str = "Món khác";
const FEATURED_CATEGORIES: &[&str] = &["Bún, Phở & Mì", "Canh", "Món kho", "Cơm & Xôi", "Gỏi & Salad"];

const CARD_SELECT: &str = r#"
    SELECT r.id, r.title, COALESCE(r.image_url, '') AS image, r.category,
           COALESCE(r.source, '') AS source, r.cook_time_minutes,
           CAST(ROUND(COALESCE(n.calories, 0)) AS INTEGER) AS calories,
           (SELECT COUNT(*) FROM recipe_ingredients i WHERE i.recipe_id = r.id) AS ingredient_count
    FROM recipes r
    LEFT JOIN recipe_nutritions n ON n.recipe_id = r.id
"#;
const CARD_ORDER: &str = " ORDER BY (r.id < 1000000), r.id ";

pub async fn page_recipes(pool: &SqlitePool, q: &PageQuery) -> Result<RecipePageDto, AppError> {
    let page = q.page.unwrap_or(1).max(1);
    let page_size = q.page_size.unwrap_or(DEFAULT_PAGE_SIZE).clamp(1, MAX_PAGE_SIZE);
    let offset = (page - 1) * page_size;
    let category = q.category.as_deref().map(str::trim).filter(|c| !c.is_empty());
    let term = q.q.as_deref().map(|t| t.trim().to_lowercase()).filter(|t| !t.is_empty());

    let (items, total) = match term {
        None => {
            let total: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes r WHERE (?1 IS NULL OR r.category = ?1)")
                .bind(category)
                .fetch_one(pool)
                .await?;
            let sql = format!("{CARD_SELECT} WHERE (?1 IS NULL OR r.category = ?1) {CARD_ORDER} LIMIT ?2 OFFSET ?3");
            let items: Vec<RecipeCardDto> = sqlx::query_as(&sql)
                .bind(category)
                .bind(page_size)
                .bind(offset)
                .fetch_all(pool)
                .await?;
            (items, total.0)
        }
        Some(term) => {
            // Lọc tên trong bộ nhớ (xem ghi chú đầu file), rồi lấy chi tiết thẻ của trang.
            let rows: Vec<(i64, String)> = sqlx::query_as(&format!(
                "SELECT r.id, r.title FROM recipes r WHERE (?1 IS NULL OR r.category = ?1) {CARD_ORDER}"
            ))
            .bind(category)
            .fetch_all(pool)
            .await?;
            let matched: Vec<i64> = rows
                .into_iter()
                .filter(|(_, title)| title.to_lowercase().contains(&term))
                .map(|(id, _)| id)
                .collect();
            let page_ids: Vec<i64> = matched.iter().skip(offset as usize).take(page_size as usize).copied().collect();
            let mut items = Vec::with_capacity(page_ids.len());
            for id in &page_ids {
                let item: RecipeCardDto = sqlx::query_as(&format!("{CARD_SELECT} WHERE r.id = ?"))
                    .bind(id)
                    .fetch_one(pool)
                    .await?;
                items.push(item);
            }
            (items, matched.len() as i64)
        }
    };

    Ok(RecipePageDto {
        has_more: offset + (items.len() as i64) < total,
        items,
        page,
        page_size,
        total,
    })
}

pub async fn categories(pool: &SqlitePool) -> Result<Vec<CategoryCountDto>, AppError> {
    let mut list: Vec<CategoryCountDto> =
        sqlx::query_as("SELECT category AS name, COUNT(*) AS count FROM recipes GROUP BY category")
            .fetch_all(pool)
            .await?;
    list.sort_by(|a, b| {
        (a.name == OTHER_CATEGORY)
            .cmp(&(b.name == OTHER_CATEGORY))
            .then(b.count.cmp(&a.count))
            .then(a.name.cmp(&b.name))
    });
    Ok(list)
}

pub async fn featured(pool: &SqlitePool) -> Result<Vec<RecipeCardDto>, AppError> {
    let mut out = Vec::new();
    for category in FEATURED_CATEGORIES {
        let sql = format!(
            "{CARD_SELECT} WHERE r.category = ? AND r.id >= 1000000 AND COALESCE(r.image_url, '') != '' ORDER BY r.id LIMIT 1"
        );
        if let Some(item) = sqlx::query_as::<_, RecipeCardDto>(&sql)
            .bind(category)
            .fetch_optional(pool)
            .await?
        {
            out.push(item);
        }
    }
    if out.is_empty() {
        let sql = format!("{CARD_SELECT} {CARD_ORDER} LIMIT 5");
        out = sqlx::query_as(&sql).fetch_all(pool).await?;
    }
    Ok(out)
}
