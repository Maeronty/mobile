use chrono::Utc;
use serde::Deserialize;
use sqlx::SqlitePool;
use std::collections::HashMap;
use crate::error::AppError;

const EMBEDDED_RECIPES_JSON: &str = include_str!("../../assets/spoonacular.json");

#[derive(Debug, Deserialize)]
pub struct RawRecipe {
    pub id: i64,
    pub title: String,
    pub image: Option<String>,
    pub source: Option<String>,
    pub category: String,
    pub time: Option<i64>,
    pub servings: Option<i64>,
    #[serde(default)]
    pub nutrients: HashMap<String, f64>,
    #[serde(default)]
    pub steps: Vec<String>,
    #[serde(default)]
    pub ingredients: Vec<RawIngredient>,
}

#[derive(Debug, Deserialize)]
pub struct RawIngredient {
    pub name: String,
    #[serde(default)]
    pub amount: f64,
    #[serde(default)]
    pub unit: String,
}

pub async fn seed_database(pool: &SqlitePool) -> Result<usize, AppError> {
    // Fast path: if recipes table already contains data, skip seeding
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(pool)
        .await
        .map_err(AppError::Database)?;

    if count.0 > 0 {
        tracing::info!("Recipes table already has {} records; skipping seed.", count.0);
        return Ok(count.0 as usize);
    }

    let raw_json = match std::fs::read_to_string("assets/spoonacular.json") {
        Ok(content) => content,
        Err(_) => match std::fs::read_to_string(
            "c:\\Users\\John Windows\\Documents\\Code\\Dart\\mobile\\assets\\spoonacular.json",
        ) {
            Ok(content) => content,
            Err(_) => EMBEDDED_RECIPES_JSON.to_string(),
        },
    };

    let recipes: Vec<RawRecipe> = serde_json::from_str(&raw_json)
        .map_err(|e| AppError::Internal(format!("Failed to parse spoonacular.json: {}", e)))?;

    let now = Utc::now().to_rfc3339();

    // Acquire a dedicated connection and use BEGIN IMMEDIATE to avoid TOCTOU race conditions
    let mut conn = pool.acquire().await.map_err(AppError::Database)?;

    sqlx::query("BEGIN IMMEDIATE")
        .execute(&mut *conn)
        .await
        .map_err(AppError::Database)?;

    let seed_result = async {
        // Double check within the immediate transaction in case another concurrent worker already seeded
        let in_tx_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
            .fetch_one(&mut *conn)
            .await
            .map_err(AppError::Database)?;

        if in_tx_count.0 > 0 {
            tracing::info!(
                "Recipes table already has {} records within transaction; skipping seed.",
                in_tx_count.0
            );
            return Ok(in_tx_count.0 as usize);
        }

        for r in &recipes {
            let cook_time = r.time.unwrap_or(30);
            let servings = r.servings.unwrap_or(2);
            let difficulty = if cook_time <= 30 {
                "Dễ"
            } else if cook_time <= 60 {
                "Trung bình"
            } else {
                "Nâng cao"
            };
            let image_url = r.image.clone().unwrap_or_default();
            let source = r
                .source
                .clone()
                .unwrap_or_else(|| "Spoonacular".to_string());
            let description = format!("Công thức món ăn {} thơm ngon, giàu dinh dưỡng.", r.title);

            let insert_recipe_res = sqlx::query(
                r#"
                INSERT OR IGNORE INTO recipes (
                    id, user_id, title, description, image_url, source, category,
                    cook_time_minutes, servings, difficulty, average_rating, total_ratings,
                    status, created_at, updated_at
                ) VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, 4.8, 12, 'Published', ?, ?)
                "#,
            )
            .bind(r.id)
            .bind(&r.title)
            .bind(&description)
            .bind(&image_url)
            .bind(&source)
            .bind(&r.category)
            .bind(cook_time)
            .bind(servings)
            .bind(difficulty)
            .bind(&now)
            .bind(&now)
            .execute(&mut *conn)
            .await
            .map_err(AppError::Database)?;

            if insert_recipe_res.rows_affected() == 0 {
                // Recipe already inserted by another concurrent transaction
                continue;
            }

            let calories = r.nutrients.get("Calories").copied().unwrap_or(0.0);
            let protein = r.nutrients.get("Protein").copied().unwrap_or(0.0);
            let fat = r.nutrients.get("Fat").copied().unwrap_or(0.0);
            let carbs = r.nutrients.get("Carbohydrates").copied().unwrap_or(0.0);
            let fiber = r.nutrients.get("Fiber").copied().unwrap_or(0.0);
            let sugar = r.nutrients.get("Sugar").copied().unwrap_or(0.0);
            let sodium = r.nutrients.get("Sodium").copied().unwrap_or(0.0);

            sqlx::query(
                r#"
                INSERT OR IGNORE INTO recipe_nutritions (
                    recipe_id, calories, protein_grams, fat_grams, carbs_grams,
                    fiber_grams, sugar_grams, sodium_mg
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                "#,
            )
            .bind(r.id)
            .bind(calories)
            .bind(protein)
            .bind(fat)
            .bind(carbs)
            .bind(fiber)
            .bind(sugar)
            .bind(sodium)
            .execute(&mut *conn)
            .await
            .map_err(AppError::Database)?;

            for (idx, ing) in r.ingredients.iter().enumerate() {
                sqlx::query(
                    r#"
                    INSERT OR IGNORE INTO recipe_ingredients (recipe_id, name, amount, unit, sort_order)
                    VALUES (?, ?, ?, ?, ?)
                    "#,
                )
                .bind(r.id)
                .bind(&ing.name)
                .bind(ing.amount)
                .bind(&ing.unit)
                .bind(idx as i64)
                .execute(&mut *conn)
                .await
                .map_err(AppError::Database)?;
            }

            for (idx, step) in r.steps.iter().enumerate() {
                sqlx::query(
                    r#"
                    INSERT OR IGNORE INTO recipe_instructions (recipe_id, step_number, content)
                    VALUES (?, ?, ?)
                    "#,
                )
                .bind(r.id)
                .bind((idx + 1) as i64)
                .bind(step)
                .execute(&mut *conn)
                .await
                .map_err(AppError::Database)?;
            }
        }

        Ok(recipes.len())
    }
    .await;

    match seed_result {
        Ok(count) => {
            sqlx::query("COMMIT")
                .execute(&mut *conn)
                .await
                .map_err(AppError::Database)?;
            tracing::info!("Successfully seeded {} recipes into database.", count);
            Ok(count)
        }
        Err(err) => {
            let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
            Err(err)
        }
    }
}
