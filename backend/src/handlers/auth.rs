use axum::{
    extract::State,
    http::StatusCode,
    Json,
};
use chrono::Utc;
use serde_json::json;

use crate::{
    error::AppError,
    middleware::AuthUser,
    models::{
        AuthResponse, ChangePasswordRequest, LoginRequest, RegisterRequest, UpdateProfileRequest,
        User, UserProfileResponse,
    },
    services::auth_service::{
        generate_jwt, hash_password, validate_email, validate_password_complexity, verify_password,
    },
    state::AppState,
};

pub async fn register(
    State(state): State<AppState>,
    Json(payload): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<AuthResponse>), AppError> {
    validate_email(&payload.email)?;
    validate_password_complexity(&payload.password)?;

    let email = payload.email.trim().to_lowercase();
    let username = payload.resolve_username();

    // Check if email already exists
    let existing_email: Option<(i64,)> =
        sqlx::query_as("SELECT id FROM users WHERE LOWER(email) = LOWER(?)")
            .bind(&email)
            .fetch_optional(&state.pool)
            .await
            .map_err(AppError::Database)?;

    if existing_email.is_some() {
        return Err(AppError::BadRequest("Email đã được sử dụng.".to_string()));
    }

    // Check if username already exists
    let existing_username: Option<(i64,)> =
        sqlx::query_as("SELECT id FROM users WHERE LOWER(username) = LOWER(?)")
            .bind(&username)
            .fetch_optional(&state.pool)
            .await
            .map_err(AppError::Database)?;

    if existing_username.is_some() {
        return Err(AppError::BadRequest("Tên đăng nhập đã được sử dụng.".to_string()));
    }

    let password_hash = hash_password(&payload.password)?;
    let display_name = payload
        .display_name
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| username.clone());

    let now = Utc::now().to_rfc3339();

    let result = sqlx::query(
        "INSERT INTO users (username, email, password_hash, display_name, avatar_url, is_active, role, created_at, updated_at) \
         VALUES (?, ?, ?, ?, NULL, 1, 'User', ?, ?)",
    )
    .bind(&username)
    .bind(&email)
    .bind(&password_hash)
    .bind(&display_name)
    .bind(&now)
    .bind(&now)
    .execute(&state.pool)
    .await
    .map_err(AppError::Database)?;

    let user_id = result.last_insert_rowid();

    let token = generate_jwt(
        user_id,
        &email,
        "User",
        &state.config.jwt_secret,
        false,
        state.config.jwt_expiration_hours,
    )?;

    let response = AuthResponse {
        user_id,
        username,
        email,
        display_name: Some(display_name),
        avatar_url: None,
        role: "User".to_string(),
        token,
    };

    Ok((StatusCode::OK, Json(response)))
}

pub async fn login(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<AuthResponse>, AppError> {
    let identifier = payload.username_or_email.trim();

    let user: Option<User> = sqlx::query_as(
        "SELECT id, username, email, password_hash, display_name, avatar_url, is_active, role, created_at, updated_at \
         FROM users WHERE LOWER(email) = LOWER(?) OR LOWER(username) = LOWER(?)",
    )
    .bind(identifier)
    .bind(identifier)
    .fetch_optional(&state.pool)
    .await
    .map_err(AppError::Database)?;

    let user = match user {
        Some(u) => u,
        None => {
            return Err(AppError::Unauthorized(
                "Email/tên đăng nhập hoặc mật khẩu không chính xác.".to_string(),
            ))
        }
    };

    if !verify_password(&payload.password, &user.password_hash) {
        return Err(AppError::Unauthorized(
            "Email/tên đăng nhập hoặc mật khẩu không chính xác.".to_string(),
        ));
    }

    if user.is_active == 0 {
        return Err(AppError::Forbidden("Tài khoản đã bị vô hiệu hóa.".to_string()));
    }

    let remember_me = payload.remember_me.unwrap_or(false);
    let token = generate_jwt(
        user.id,
        &user.email,
        &user.role,
        &state.config.jwt_secret,
        remember_me,
        state.config.jwt_expiration_hours,
    )?;

    let response = AuthResponse {
        user_id: user.id,
        username: user.username,
        email: user.email,
        display_name: user.display_name,
        avatar_url: user.avatar_url,
        role: user.role,
        token,
    };

    Ok(Json(response))
}

pub async fn get_profile(
    State(state): State<AppState>,
    AuthUser(claims): AuthUser,
) -> Result<Json<UserProfileResponse>, AppError> {
    let user_id = claims
        .sub
        .parse::<i64>()
        .map_err(|_| AppError::Unauthorized("ID người dùng không hợp lệ.".to_string()))?;

    let user: Option<User> = sqlx::query_as(
        "SELECT id, username, email, password_hash, display_name, avatar_url, is_active, role, created_at, updated_at \
         FROM users WHERE id = ?",
    )
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(AppError::Database)?;

    let user = match user {
        Some(u) => u,
        None => return Err(AppError::NotFound("Người dùng không tồn tại.".to_string())),
    };

    let response = UserProfileResponse {
        user_id: user.id,
        id: user.id,
        username: user.username,
        email: user.email,
        display_name: user.display_name.clone(),
        name: user.display_name,
        avatar_url: user.avatar_url,
        role: user.role,
        is_active: user.is_active != 0,
        created_at: user.created_at,
    };

    Ok(Json(response))
}

pub async fn update_profile(
    State(state): State<AppState>,
    AuthUser(claims): AuthUser,
    Json(payload): Json<UpdateProfileRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = claims
        .sub
        .parse::<i64>()
        .map_err(|_| AppError::Unauthorized("ID người dùng không hợp lệ.".to_string()))?;

    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE id = ?")
        .bind(user_id)
        .fetch_one(&state.pool)
        .await
        .map_err(AppError::Database)?;

    if count.0 == 0 {
        return Err(AppError::NotFound("Người dùng không tồn tại.".to_string()));
    }

    let now = Utc::now().to_rfc3339();

    if payload.display_name.is_some() && payload.avatar_url.is_some() {
        sqlx::query("UPDATE users SET display_name = ?, avatar_url = ?, updated_at = ? WHERE id = ?")
            .bind(payload.display_name)
            .bind(payload.avatar_url)
            .bind(&now)
            .bind(user_id)
            .execute(&state.pool)
            .await
            .map_err(AppError::Database)?;
    } else if let Some(dn) = payload.display_name {
        sqlx::query("UPDATE users SET display_name = ?, updated_at = ? WHERE id = ?")
            .bind(dn)
            .bind(&now)
            .bind(user_id)
            .execute(&state.pool)
            .await
            .map_err(AppError::Database)?;
    } else if let Some(av) = payload.avatar_url {
        sqlx::query("UPDATE users SET avatar_url = ?, updated_at = ? WHERE id = ?")
            .bind(av)
            .bind(&now)
            .bind(user_id)
            .execute(&state.pool)
            .await
            .map_err(AppError::Database)?;
    }

    Ok(Json(json!({
        "message": "Cập nhật thành công",
        "success": true
    })))
}

pub async fn change_password(
    State(state): State<AppState>,
    AuthUser(claims): AuthUser,
    Json(payload): Json<ChangePasswordRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = claims
        .sub
        .parse::<i64>()
        .map_err(|_| AppError::Unauthorized("ID người dùng không hợp lệ.".to_string()))?;

    let user: Option<(String,)> =
        sqlx::query_as("SELECT password_hash FROM users WHERE id = ?")
            .bind(user_id)
            .fetch_optional(&state.pool)
            .await
            .map_err(AppError::Database)?;

    let (current_hash,) = match user {
        Some(h) => h,
        None => return Err(AppError::NotFound("Người dùng không tồn tại.".to_string())),
    };

    if !verify_password(&payload.current_password, &current_hash) {
        return Err(AppError::BadRequest("Mật khẩu hiện tại không đúng.".to_string()));
    }

    validate_password_complexity(&payload.new_password)?;

    let new_hash = hash_password(&payload.new_password)?;
    let now = Utc::now().to_rfc3339();

    sqlx::query("UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?")
        .bind(&new_hash)
        .bind(&now)
        .bind(user_id)
        .execute(&state.pool)
        .await
        .map_err(AppError::Database)?;

    Ok(Json(json!({
        "message": "Đổi mật khẩu thành công",
        "success": true
    })))
}

pub async fn upgrade_to_vip(
    State(state): State<AppState>,
    AuthUser(claims): AuthUser,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = claims
        .sub
        .parse::<i64>()
        .map_err(|_| AppError::Unauthorized("ID người dùng không hợp lệ.".to_string()))?;

    let now = Utc::now().to_rfc3339();
    let result = sqlx::query("UPDATE users SET role = 'VIP', updated_at = ? WHERE id = ?")
        .bind(&now)
        .bind(user_id)
        .execute(&state.pool)
        .await
        .map_err(AppError::Database)?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("Người dùng không tồn tại.".to_string()));
    }

    Ok(Json(json!({
        "message": "Nâng cấp tài khoản VIP thành công!",
        "role": "VIP"
    })))
}
