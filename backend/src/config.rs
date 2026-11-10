use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub port: u16,
    pub database_url: String,
    pub jwt_secret: String,
    pub jwt_expiration_hours: i64,
}

impl Config {
    pub fn load() -> Self {
        dotenvy::dotenv().ok();

        let port = env::var("PORT")
            .ok()
            .and_then(|p| p.parse::<u16>().ok())
            .unwrap_or(8787);

        let database_url = env::var("DATABASE_URL")
            .unwrap_or_else(|_| "sqlite://food_tip.db".to_string());

        let jwt_secret = env::var("JWT_SECRET")
            .unwrap_or_else(|_| "FoodTipSystemSuperSecretKey2026SecureJwt!".to_string());

        let jwt_expiration_hours = env::var("JWT_EXPIRATION_HOURS")
            .ok()
            .and_then(|h| h.parse::<i64>().ok())
            .unwrap_or(2);

        Self {
            port,
            database_url,
            jwt_secret,
            jwt_expiration_hours,
        }
    }
}
