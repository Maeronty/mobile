use chrono::Utc;
use sqlx::SqlitePool;
use std::collections::HashSet;
use tokio::sync::Mutex;

use crate::error::AppError;
use crate::models::pantry::{
    AddPantryResponse, CreatePantryItemRequest, CreatePantryPayload, PantryItem, PantryItemDto,
    PantryListResponse, UpdatePantryItemRequest,
};

static PANTRY_UPSERT_LOCK: Mutex<()> = Mutex::const_new(());

async fn verify_user_exists(pool: &SqlitePool, user_id: i64) -> Result<(), AppError> {
    let user_exists: Option<(i64,)> = sqlx::query_as("SELECT id FROM users WHERE id = ?")
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(AppError::Database)?;

    if user_exists.is_none() {
        return Err(AppError::Unauthorized(
            "Người dùng không tồn tại.".to_string(),
        ));
    }
    Ok(())
}

/// Retrieve all pantry items for a given user ordered by created_at DESC,
/// plus a unique list of ingredient names.
pub async fn get_pantry(
    pool: &SqlitePool,
    user_id: i64,
) -> Result<PantryListResponse, AppError> {
    verify_user_exists(pool, user_id).await?;

    let items: Vec<PantryItem> = sqlx::query_as(
        r#"
        SELECT id, user_id, name, amount, unit, category, created_at, updated_at
        FROM pantry_items
        WHERE user_id = ?
        ORDER BY created_at DESC, id DESC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(AppError::Database)?;

    let mut seen = HashSet::new();
    let mut ingredient_names = Vec::new();
    let mut dtos = Vec::with_capacity(items.len());

    for item in items {
        let norm = item.name.trim().to_lowercase();
        if !norm.is_empty() && seen.insert(norm) {
            ingredient_names.push(item.name.clone());
        }
        dtos.push(PantryItemDto::from(item));
    }

    Ok(PantryListResponse {
        items: dtos,
        ingredient_names,
    })
}

/// Helper to add or update a single item by normalized name
async fn upsert_single_item(
    pool: &SqlitePool,
    user_id: i64,
    req: CreatePantryItemRequest,
) -> Result<PantryItemDto, AppError> {
    let _guard = PANTRY_UPSERT_LOCK.lock().await;

    let raw_name = match req.name.as_deref() {
        Some(n) => n.trim(),
        None => {
            return Err(AppError::BadRequest(
                "Tên nguyên liệu không được để trống.".to_string(),
            ))
        }
    };

    if raw_name.is_empty() {
        return Err(AppError::BadRequest(
            "Tên nguyên liệu không được để trống.".to_string(),
        ));
    }

    let norm_name = raw_name.to_lowercase();

    // Check if item already exists for this user (case-insensitive)
    let existing: Option<PantryItem> = sqlx::query_as(
        r#"
        SELECT id, user_id, name, amount, unit, category, created_at, updated_at
        FROM pantry_items
        WHERE user_id = ? AND LOWER(TRIM(name)) = ?
        "#,
    )
    .bind(user_id)
    .bind(&norm_name)
    .fetch_optional(pool)
    .await
    .map_err(AppError::Database)?;

    let now = Utc::now().to_rfc3339();

    if let Some(mut item) = existing {
        // If amount was provided, accumulate or update it
        if let Some(amt) = req.amount {
            item.amount = Some(item.amount.unwrap_or(0.0) + amt);
        }
        if let Some(unit) = req.unit {
            let u_trimmed = unit.trim();
            if !u_trimmed.is_empty() {
                item.unit = Some(u_trimmed.to_string());
            }
        }
        let notes_val = req.notes.or(req.category);
        if let Some(notes) = notes_val {
            let n_trimmed = notes.trim();
            if !n_trimmed.is_empty() {
                item.category = Some(n_trimmed.to_string());
            }
        }
        item.updated_at = now;

        sqlx::query(
            r#"
            UPDATE pantry_items
            SET amount = ?, unit = ?, category = ?, updated_at = ?
            WHERE id = ? AND user_id = ?
            "#,
        )
        .bind(item.amount)
        .bind(&item.unit)
        .bind(&item.category)
        .bind(&item.updated_at)
        .bind(item.id)
        .bind(user_id)
        .execute(pool)
        .await
        .map_err(AppError::Database)?;

        Ok(PantryItemDto::from(item))
    } else {
        let amount = req.amount.unwrap_or(1.0);
        let unit = req.unit.unwrap_or_default();
        let category = req.notes.or(req.category);

        let res = sqlx::query(
            r#"
            INSERT INTO pantry_items (user_id, name, amount, unit, category, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(user_id)
        .bind(&norm_name)
        .bind(amount)
        .bind(&unit)
        .bind(&category)
        .bind(&now)
        .bind(&now)
        .execute(pool)
        .await
        .map_err(AppError::Database)?;

        let id = res.last_insert_rowid();
        let item = PantryItem {
            id,
            user_id,
            name: norm_name,
            amount: Some(amount),
            unit: Some(unit),
            category,
            created_at: now.clone(),
            updated_at: now,
        };

        Ok(PantryItemDto::from(item))
    }
}

/// Add single or batch pantry items using `CreatePantryItemRequest`
pub async fn add_pantry_item(
    pool: &SqlitePool,
    user_id: i64,
    req: CreatePantryItemRequest,
) -> Result<(PantryItemDto, String), AppError> {
    verify_user_exists(pool, user_id).await?;

    if let Some(names) = req.names {
        let valid_names: Vec<String> = names
            .into_iter()
            .map(|n| n.trim().to_string())
            .filter(|n| !n.is_empty())
            .collect();

        if valid_names.is_empty() {
            return Err(AppError::BadRequest(
                "Danh sách nguyên liệu không được để trống.".to_string(),
            ));
        }

        let count = valid_names.len();
        let mut dtos = Vec::with_capacity(count);
        for name in valid_names {
            let single_req = CreatePantryItemRequest {
                name: Some(name),
                amount: req.amount.or(Some(1.0)),
                unit: req.unit.clone().or_else(|| Some(String::new())),
                notes: req.notes.clone(),
                category: req.category.clone(),
                names: None,
            };
            dtos.push(upsert_single_item(pool, user_id, single_req).await?);
        }

        let dto = dtos
            .into_iter()
            .next()
            .expect("valid_names is non-empty, so at least one item was upserted");
        let msg = format!("Đã thêm {count} nguyên liệu vào tủ lạnh thành công.");
        Ok((dto, msg))
    } else {
        let dto = upsert_single_item(pool, user_id, req).await?;
        Ok((
            dto,
            "Đã thêm nguyên liệu vào tủ lạnh thành công.".to_string(),
        ))
    }
}

/// Add pantry items from top-level `CreatePantryPayload` (single, batch names, or batch objects)
pub async fn add_pantry_payload(
    pool: &SqlitePool,
    user_id: i64,
    payload: CreatePantryPayload,
) -> Result<AddPantryResponse, AppError> {
    verify_user_exists(pool, user_id).await?;

    let reqs = payload.into_requests();
    if reqs.is_empty() {
        return Err(AppError::BadRequest(
            "Danh sách nguyên liệu không được để trống.".to_string(),
        ));
    }

    let mut dtos = Vec::with_capacity(reqs.len());
    for req in reqs {
        let dto = upsert_single_item(pool, user_id, req).await?;
        dtos.push(dto);
    }

    let count = dtos.len();
    let message = if count == 1 {
        "Đã thêm nguyên liệu vào tủ lạnh thành công.".to_string()
    } else {
        format!("Đã thêm {count} nguyên liệu vào tủ lạnh thành công.")
    };
    Ok(AddPantryResponse {
        message,
        item: dtos.first().cloned(),
        items: Some(dtos),
        count: Some(count),
    })
}

/// Update an existing pantry item with ownership verification
pub async fn update_pantry_item(
    pool: &SqlitePool,
    user_id: i64,
    item_id: i64,
    req: UpdatePantryItemRequest,
) -> Result<PantryItemDto, AppError> {
    verify_user_exists(pool, user_id).await?;

    let existing: Option<PantryItem> = sqlx::query_as(
        r#"
        SELECT id, user_id, name, amount, unit, category, created_at, updated_at
        FROM pantry_items
        WHERE id = ?
        "#,
    )
    .bind(item_id)
    .fetch_optional(pool)
    .await
    .map_err(AppError::Database)?;

    let mut item = match existing {
        Some(it) => it,
        None => {
            return Err(AppError::NotFound(
                "Không tìm thấy nguyên liệu trong tủ lạnh.".to_string(),
            ))
        }
    };

    if item.user_id != user_id {
        return Err(AppError::NotFound(
            "Không tìm thấy nguyên liệu trong tủ lạnh.".to_string(),
        ));
    }

    if let Some(n) = req.name {
        let trimmed = n.trim();
        if !trimmed.is_empty() {
            item.name = trimmed.to_lowercase();
        }
    }

    if req.amount.is_some() {
        item.amount = req.amount;
    }

    if req.unit.is_some() {
        item.unit = req.unit;
    }

    let notes_val = req.notes.or(req.category);
    if notes_val.is_some() {
        item.category = notes_val;
    }

    let now = Utc::now().to_rfc3339();
    item.updated_at = now;

    sqlx::query(
        r#"
        UPDATE pantry_items
        SET name = ?, amount = ?, unit = ?, category = ?, updated_at = ?
        WHERE id = ? AND user_id = ?
        "#,
    )
    .bind(&item.name)
    .bind(item.amount)
    .bind(&item.unit)
    .bind(&item.category)
    .bind(&item.updated_at)
    .bind(item.id)
    .bind(user_id)
    .execute(pool)
    .await
    .map_err(AppError::Database)?;

    Ok(PantryItemDto::from(item))
}

/// Delete an item by ID with ownership verification
pub async fn delete_pantry_item(
    pool: &SqlitePool,
    user_id: i64,
    item_id: i64,
) -> Result<(), AppError> {
    verify_user_exists(pool, user_id).await?;

    let res = sqlx::query("DELETE FROM pantry_items WHERE id = ? AND user_id = ?")
        .bind(item_id)
        .bind(user_id)
        .execute(pool)
        .await
        .map_err(AppError::Database)?;

    // Another user's item is reported the same as a missing one.
    if res.rows_affected() == 0 {
        return Err(AppError::NotFound(
            "Không tìm thấy nguyên liệu trong tủ lạnh.".to_string(),
        ));
    }
    Ok(())
}

/// Delete an item matching normalized name for user
pub async fn delete_pantry_by_name(
    pool: &SqlitePool,
    user_id: i64,
    name: &str,
) -> Result<(), AppError> {
    verify_user_exists(pool, user_id).await?;

    let norm = name.trim().to_lowercase();
    if norm.is_empty() {
        return Err(AppError::BadRequest(
            "Tên nguyên liệu không hợp lệ.".to_string(),
        ));
    }

    let res = sqlx::query(
        "DELETE FROM pantry_items WHERE user_id = ? AND LOWER(TRIM(name)) = ?"
    )
    .bind(user_id)
    .bind(&norm)
    .execute(pool)
    .await
    .map_err(AppError::Database)?;

    if res.rows_affected() == 0 {
        return Err(AppError::NotFound(format!(
            "Không tìm thấy nguyên liệu '{}' trong tủ lạnh.",
            name
        )));
    }

    Ok(())
}

/// Clear all pantry items for the given user, returning the deleted count
pub async fn clear_pantry(pool: &SqlitePool, user_id: i64) -> Result<usize, AppError> {
    verify_user_exists(pool, user_id).await?;

    let res = sqlx::query("DELETE FROM pantry_items WHERE user_id = ?")
        .bind(user_id)
        .execute(pool)
        .await
        .map_err(AppError::Database)?;

    Ok(res.rows_affected() as usize)
}
