use sqlx::SqlitePool;
use std::sync::Arc;
use crate::config::Config;
use crate::services::ai_service::{AiConfig, AiService};

#[derive(Clone)]
pub struct AppState {
    pub pool: SqlitePool,
    pub config: Arc<Config>,
    /// Gemini + Spoonacular; cấu hình đọc từ biến môi trường.
    pub ai: Arc<AiService>,
    /// HTTP client dùng chung cho proxy ảnh (`/api/image`).
    pub http: reqwest::Client,
}

impl AppState {
    pub fn new(pool: SqlitePool, config: Config) -> Self {
        Self::with_ai(pool, config, AiConfig::from_env())
    }

    /// Dùng trong test để trỏ Gemini/Spoonacular về server giả.
    pub fn with_ai(pool: SqlitePool, config: Config, ai: AiConfig) -> Self {
        Self {
            pool,
            config: Arc::new(config),
            ai: Arc::new(AiService::new(ai)),
            http: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(20))
                .user_agent("BepViet/1.0 (image proxy)")
                .build()
                .expect("Không tạo được HTTP client"),
        }
    }
}
