//! =============================================================================
//! SEED MÓN VIỆT (Món Ngon Mỗi Ngày) — `assets/vietnamese_recipes.json`
//! =============================================================================
//!
//! File dữ liệu được tạo bởi `tools/import_monngon.py` từ dữ liệu đã cào của
//! project cũ (≈ 1.800 món, id từ 1_000_000 để không trùng id Spoonacular).
//!
//! FLOW (`seed_vietnamese_recipes`, gọi trong main sau `seed_database`)
//!   1. Đọc file trong thư mục chạy (`assets/...`), không có thì dùng bản nhúng
//!      sẵn trong binary.
//!   2. Đếm số món Việt đã có trong DB; đủ rồi → bỏ qua (khởi động nhanh).
//!   3. Thiếu → thêm trong MỘT transaction, `INSERT OR IGNORE` nên món đã có
//!      không bị ghi đè và DB cũ (chỉ có 8 món Spoonacular) vẫn được bổ sung.
//!
//! KHÔNG BỊA DỮ LIỆU
//!   Trang nguồn không có thời gian nấu, khẩu phần, dinh dưỡng, đánh giá:
//!     - cook_time_minutes = 0, servings = 0  → app hiển thị "—".
//!     - KHÔNG tạo dòng recipe_nutritions → `/catalog` trả `nutrients: {}`.
//!     - average_rating = 0, total_ratings = 0.
//!   Độ khó ước lượng theo số nguyên liệu (≤ 7 Dễ, ≤ 11 Trung bình, còn lại Nâng cao).
//!
//! LƯU Ý
//!   Tách riêng khỏi `seed_database` để các test hiện có (giả định 8 món
//!   Spoonacular) không bị ảnh hưởng.
//! =============================================================================

use chrono::Utc;
use sqlx::SqlitePool;

use super::seed::RawRecipe;
use crate::error::AppError;

const EMBEDDED_VIETNAMESE_JSON: &str = include_str!("../../assets/vietnamese_recipes.json");
pub const VIETNAMESE_ID_BASE: i64 = 1_000_000;

fn load_recipes() -> Result<Vec<RawRecipe>, AppError> {
    let raw = std::fs::read_to_string("assets/vietnamese_recipes.json")
        .unwrap_or_else(|_| EMBEDDED_VIETNAMESE_JSON.to_string());
    serde_json::from_str(&raw)
        .map_err(|e| AppError::Internal(format!("Không đọc được vietnamese_recipes.json: {e}")))
}

fn difficulty(ingredient_count: usize) -> &'static str {
    match ingredient_count {
        0..=7 => "Dễ",
        8..=11 => "Trung bình",
        _ => "Nâng cao",
    }
}

/// Trả về số món Việt có trong DB sau khi seed.
pub async fn seed_vietnamese_recipes(pool: &SqlitePool) -> Result<usize, AppError> {
    let recipes = load_recipes()?;

    let existing: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes WHERE id >= ?")
        .bind(VIETNAMESE_ID_BASE)
        .fetch_one(pool)
        .await?;
    if existing.0 as usize >= recipes.len() {
        tracing::info!("Đã có {} món Việt; bỏ qua seed.", existing.0);
        return Ok(existing.0 as usize);
    }

    let now = Utc::now().to_rfc3339();
    let mut tx = pool.begin().await?;
    let mut inserted = 0usize;

    for r in &recipes {
        let source = r.source.clone().unwrap_or_else(|| "Món Ngon Mỗi Ngày".to_string());
        let description = format!("Công thức {} theo {}.", r.title, source);
        let result = sqlx::query(
            r#"
            INSERT OR IGNORE INTO recipes (
                id, user_id, title, description, image_url, source, category,
                cook_time_minutes, servings, difficulty, average_rating, total_ratings,
                status, created_at, updated_at
            ) VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 'Published', ?, ?)
            "#,
        )
        .bind(r.id)
        .bind(&r.title)
        .bind(&description)
        .bind(r.image.clone().unwrap_or_default())
        .bind(&source)
        .bind(&r.category)
        .bind(r.time.unwrap_or(0))
        .bind(r.servings.unwrap_or(0))
        .bind(difficulty(r.ingredients.len()))
        .bind(&now)
        .bind(&now)
        .execute(&mut *tx)
        .await?;
        if result.rows_affected() == 0 {
            continue;
        }
        inserted += 1;

        if !r.nutrients.is_empty() {
            sqlx::query(
                "INSERT OR IGNORE INTO recipe_nutritions (recipe_id, calories, protein_grams, fat_grams, carbs_grams, fiber_grams, sugar_grams, sodium_mg) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind(r.id)
            .bind(r.nutrients.get("Calories").copied().unwrap_or(0.0))
            .bind(r.nutrients.get("Protein").copied().unwrap_or(0.0))
            .bind(r.nutrients.get("Fat").copied().unwrap_or(0.0))
            .bind(r.nutrients.get("Carbohydrates").copied().unwrap_or(0.0))
            .bind(r.nutrients.get("Fiber").copied().unwrap_or(0.0))
            .bind(r.nutrients.get("Sugar").copied().unwrap_or(0.0))
            .bind(r.nutrients.get("Sodium").copied().unwrap_or(0.0))
            .execute(&mut *tx)
            .await?;
        }

        for (idx, ing) in r.ingredients.iter().enumerate() {
            sqlx::query("INSERT INTO recipe_ingredients (recipe_id, name, amount, unit, sort_order) VALUES (?, ?, ?, ?, ?)")
                .bind(r.id)
                .bind(&ing.name)
                .bind(ing.amount)
                .bind(&ing.unit)
                .bind(idx as i64)
                .execute(&mut *tx)
                .await?;
        }
        for (idx, step) in r.steps.iter().enumerate() {
            sqlx::query("INSERT INTO recipe_instructions (recipe_id, step_number, content) VALUES (?, ?, ?)")
                .bind(r.id)
                .bind((idx + 1) as i64)
                .bind(step)
                .execute(&mut *tx)
                .await?;
        }
    }

    tx.commit().await?;
    tracing::info!("Đã thêm {} món Việt vào database.", inserted);
    Ok(existing.0 as usize + inserted)
}
