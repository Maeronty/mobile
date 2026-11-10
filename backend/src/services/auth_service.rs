use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::sync::LazyLock;

use crate::error::AppError;

static RE_LOWER: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[a-z]").unwrap());
static RE_UPPER: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[A-Z]").unwrap());
static RE_DIGIT: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\d").unwrap());
static RE_SPECIAL: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[^\da-zA-Z]").unwrap());

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,
    pub email: String,
    pub role: String,
    pub exp: usize,
}

pub fn validate_email(email: &str) -> Result<(), AppError> {
    let trimmed = email.trim();
    if trimmed.len() < 5 || !trimmed.contains('@') || !trimmed.contains('.') {
        return Err(AppError::BadRequest("Email không hợp lệ.".to_string()));
    }
    Ok(())
}

pub fn validate_password_complexity(password: &str) -> Result<(), AppError> {
    let err = || {
        AppError::BadRequest(
            "Mật khẩu phải bao gồm chữ hoa, chữ thường, số và ký tự đặc biệt (tối thiểu 8 ký tự)."
                .to_string(),
        )
    };

    if password.chars().count() < 8 {
        return Err(err());
    }

    if !RE_LOWER.is_match(password)
        || !RE_UPPER.is_match(password)
        || !RE_DIGIT.is_match(password)
        || !RE_SPECIAL.is_match(password)
    {
        return Err(err());
    }

    Ok(())
}

pub fn hash_password(password: &str) -> Result<String, AppError> {
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let hash = argon2
        .hash_password(password.as_bytes(), &salt)
        .map_err(|e| AppError::Internal(format!("Lỗi mã hóa mật khẩu: {}", e)))?
        .to_string();
    Ok(hash)
}

pub fn verify_password(password: &str, hash: &str) -> bool {
    if hash.starts_with("$2a$") || hash.starts_with("$2b$") || hash.starts_with("$2y$") {
        bcrypt::verify(password, hash).unwrap_or(false)
    } else {
        match PasswordHash::new(hash) {
            Ok(parsed_hash) => Argon2::default()
                .verify_password(password.as_bytes(), &parsed_hash)
                .is_ok(),
            Err(_) => false,
        }
    }
}

pub fn generate_jwt(
    user_id: i64,
    email: &str,
    role: &str,
    secret: &str,
    remember_me: bool,
    default_expiration_hours: i64,
) -> Result<String, AppError> {
    let now = Utc::now();
    let duration = if remember_me {
        Duration::days(30)
    } else {
        Duration::hours(default_expiration_hours)
    };
    let exp = (now + duration).timestamp() as usize;

    let claims = Claims {
        sub: user_id.to_string(),
        email: email.to_string(),
        role: role.to_string(),
        exp,
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .map_err(|e| AppError::Internal(format!("Lỗi tạo JWT: {}", e)))
}

pub fn verify_jwt(token: &str, secret: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
    let token_data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )?;
    Ok(token_data.claims)
}
