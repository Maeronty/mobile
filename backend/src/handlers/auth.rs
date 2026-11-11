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
        generate_jwt, hash_password_blocking, validate_email, validate_password_complexity,
        verify_password_blocking,
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

    let password_hash = hash_password_blocking(payload.password).await?;
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
    .map_err(map_insert_user_error)?;

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

    if !verify_password_blocking(payload.password, user.password_hash).await? {
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
    let user_id = claims.user_id()?;

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
    let user_id = claims.user_id()?;
    let now = Utc::now().to_rfc3339();

    let result = sqlx::query(
        "UPDATE users SET display_name = COALESCE(?, display_name), \
         avatar_url = COALESCE(?, avatar_url), updated_at = ? WHERE id = ?",
    )
    .bind(payload.display_name)
    .bind(payload.avatar_url)
    .bind(&now)
    .bind(user_id)
    .execute(&state.pool)
    .await
    .map_err(AppError::Database)?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("Người dùng không tồn tại.".to_string()));
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
    let user_id = claims.user_id()?;

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

    if !verify_password_blocking(payload.current_password, current_hash).await? {
        return Err(AppError::BadRequest("Mật khẩu hiện tại không đúng.".to_string()));
    }

    validate_password_complexity(&payload.new_password)?;

    let new_hash = hash_password_blocking(payload.new_password).await?;
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

/// Maps a failed `INSERT INTO users` to a 400 when a concurrent request won the UNIQUE race.
fn map_insert_user_error(e: sqlx::Error) -> AppError {
    let message = match e.as_database_error() {
        Some(db) if db.is_unique_violation() && db.message().contains("users.email") => {
            "Email đã được sử dụng."
        }
        Some(db) if db.is_unique_violation() => "Tên đăng nhập đã được sử dụng.",
        _ => return AppError::Database(e),
    };
    AppError::BadRequest(message.to_string())
}
