use chrono::Utc;
use sqlx::SqlitePool;
use std::collections::{HashMap, HashSet};

use crate::error::AppError;
use crate::models::favorite::{SyncFavoritesResponse, ToggleFavoriteResponse};
use crate::models::recipe::{Recipe, RecipeIngredient, RecipeSummaryDto};

pub async fn toggle_favorite(
    pool: &SqlitePool,
    user_id: i64,
    recipe_id: i64,
) -> Result<ToggleFavoriteResponse, AppError> {
    // 1. Verify user exists
    let user_exists: Option<(i64,)> = sqlx::query_as("SELECT id FROM users WHERE id = ?")
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(AppError::Database)?;

    if user_exists.is_none() {
        return Err(AppError::Unauthorized("Người dùng không tồn tại.".to_string()));
    }

    // 2. Verify recipe exists in `recipes` table
    let recipe_exists: Option<(i64,)> = sqlx::query_as("SELECT id FROM recipes WHERE id = ?")
        .bind(recipe_id)
        .fetch_optional(pool)
        .await
        .map_err(AppError::Database)?;

    if recipe_exists.is_none() {
        return Err(AppError::NotFound("Công thức món ăn không tồn tại.".to_string()));
    }

    // 3. Attempt to delete existing favorite atomically
    let del_res = sqlx::query("DELETE FROM user_favorites WHERE user_id = ? AND recipe_id = ?")
        .bind(user_id)
        .bind(recipe_id)
        .execute(pool)
        .await
        .map_err(AppError::Database)?;

    if del_res.rows_affected() > 0 {
        Ok(ToggleFavoriteResponse {
            message: "Recipe removed from favorites".to_string(),
            is_favorited: false,
        })
    } else {
        let now = Utc::now().to_rfc3339();
        sqlx::query(
            "INSERT INTO user_favorites (user_id, recipe_id, created_at) VALUES (?, ?, ?) ON CONFLICT (user_id, recipe_id) DO NOTHING",
        )
        .bind(user_id)
        .bind(recipe_id)
        .bind(&now)
        .execute(pool)
        .await
        .map_err(AppError::Database)?;

        Ok(ToggleFavoriteResponse {
            message: "Recipe added to favorites".to_string(),
            is_favorited: true,
        })
    }
}

pub async fn get_user_favorites(
    pool: &SqlitePool,
    user_id: i64,
) -> Result<Vec<RecipeSummaryDto>, AppError> {
    let recipes: Vec<Recipe> = sqlx::query_as(
        r#"
        SELECT r.*
        FROM recipes r
        INNER JOIN user_favorites uf ON r.id = uf.recipe_id
        WHERE uf.user_id = ?
        ORDER BY uf.created_at DESC, r.id ASC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(AppError::Database)?;

    if recipes.is_empty() {
        return Ok(vec![]);
    }

    let ingredients: Vec<RecipeIngredient> = sqlx::query_as(
        "SELECT * FROM recipe_ingredients \
         WHERE recipe_id IN (SELECT recipe_id FROM user_favorites WHERE user_id = ?) \
         ORDER BY sort_order ASC, id ASC",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(AppError::Database)?;

    let mut ing_names_map: HashMap<i64, Vec<String>> = HashMap::new();
    for ing in ingredients {
        ing_names_map
            .entry(ing.recipe_id)
            .or_default()
            .push(ing.name);
    }

    let summaries: Vec<RecipeSummaryDto> = recipes
        .into_iter()
        .map(|r| {
            let ing_names = ing_names_map.remove(&r.id).unwrap_or_default();
            RecipeSummaryDto {
                recipe_id: r.id,
                recipe_id_upper: r.id,
                id: r.id,
                title: r.title,
                image_url: r.image_url.unwrap_or_default(),
                cook_time_minutes: r.cook_time_minutes,
                difficulty: r.difficulty,
                average_rating: r.average_rating,
                total_ratings: r.total_ratings,
                category: r.category.clone(),
                tags: vec![r.category],
                ingredient_names: ing_names,
                is_favorited: true,
                user_rating: None,
            }
        })
        .collect();

    Ok(summaries)
}

pub async fn sync_favorites(
    pool: &SqlitePool,
    user_id: i64,
    recipe_ids: Vec<i64>,
) -> Result<SyncFavoritesResponse, AppError> {
    // 1. Verify user exists
    let user_exists: Option<(i64,)> = sqlx::query_as("SELECT id FROM users WHERE id = ?")
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(AppError::Database)?;

    if user_exists.is_none() {
        return Err(AppError::Unauthorized("Người dùng không tồn tại.".to_string()));
    }

    // 2. Deduplicate incoming IDs
    let mut seen = HashSet::new();
    let unique_ids: Vec<i64> = recipe_ids.into_iter().filter(|id| seen.insert(*id)).collect();

    if unique_ids.is_empty() {
        return Err(AppError::BadRequest(
            "Danh sách món ăn yêu thích không được rỗng.".to_string(),
        ));
    }

    // 3. Insert only ids that exist in `recipes`: one statement per chunk, all-or-nothing.
    let now = Utc::now().to_rfc3339();
    let mut tx = pool.begin().await.map_err(AppError::Database)?;
    let mut synced_count: usize = 0;

    for chunk in unique_ids.chunks(100) {
        let placeholders = vec!["?"; chunk.len()].join(",");
        let sql = format!(
            "INSERT OR IGNORE INTO user_favorites (user_id, recipe_id, created_at) \
             SELECT ?, id, ? FROM recipes WHERE id IN ({placeholders})"
        );
        let mut q = sqlx::query(&sql).bind(user_id).bind(&now);
        for id in chunk {
            q = q.bind(*id);
        }
        let res = q.execute(&mut *tx).await.map_err(AppError::Database)?;
        synced_count += res.rows_affected() as usize;
    }

    tx.commit().await.map_err(AppError::Database)?;

    Ok(SyncFavoritesResponse {
        message: "Favorites synchronized".to_string(),
        synced_count,
    })
}
