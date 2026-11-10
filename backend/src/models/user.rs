use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct User {
    pub id: i64,
    pub username: String,
    pub email: String,
    pub password_hash: String,
    pub display_name: Option<String>,
    pub avatar_url: Option<String>,
    pub is_active: i64,
    pub role: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub username: Option<String>,
    #[serde(alias = "name")]
    pub display_name: Option<String>,
}

impl RegisterRequest {
    pub fn resolve_username(&self) -> String {
        if let Some(ref u) = self.username {
            let trimmed = u.trim();
            if !trimmed.is_empty() {
                return trimmed.to_string();
            }
        }
        let prefix = self
            .email
            .split('@')
            .next()
            .unwrap_or("user")
            .trim();
        let prefix = if prefix.is_empty() { "user" } else { prefix };
        let uuid_str = Uuid::new_v4().simple().to_string();
        let suffix = &uuid_str[..6];
        format!("{}_{}", prefix, suffix)
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LoginRequest {
    #[serde(alias = "email", alias = "username", alias = "userName")]
    pub username_or_email: String,
    pub password: String,
    pub remember_me: Option<bool>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AuthResponse {
    #[serde(alias = "id")]
    pub user_id: i64,
    pub username: String,
    pub email: String,
    #[serde(alias = "name")]
    pub display_name: Option<String>,
    pub avatar_url: Option<String>,
    pub role: String,
    pub token: String,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UserProfileResponse {
    pub user_id: i64,
    pub id: i64,
    pub username: String,
    pub email: String,
    pub display_name: Option<String>,
    pub name: Option<String>,
    pub avatar_url: Option<String>,
    pub role: String,
    pub is_active: bool,
    pub created_at: String,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateProfileRequest {
    #[serde(alias = "name")]
    pub display_name: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ChangePasswordRequest {
    #[serde(alias = "oldPassword")]
    pub current_password: String,
    pub new_password: String,
}
