use sqlx::{
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions},
    SqlitePool,
};
use std::str::FromStr;
use std::time::Duration;
use crate::error::AppError;

pub async fn create_pool(database_url: &str) -> Result<SqlitePool, AppError> {
    let mut options = SqliteConnectOptions::from_str(database_url)
        .map_err(|e| AppError::Internal(format!("Invalid database URL: {}", e)))?
        .create_if_missing(true)
        .foreign_keys(true)
        .busy_timeout(Duration::from_secs(5));

    if !database_url.contains(":memory:") {
        options = options.journal_mode(SqliteJournalMode::Wal);
    }

    let pool = SqlitePoolOptions::new()
        .max_connections(10)
        .acquire_timeout(Duration::from_secs(5))
        .connect_with(options)
        .await
        .map_err(AppError::Database)?;

    Ok(pool)
}

pub async fn run_migrations(pool: &SqlitePool) -> Result<(), AppError> {
    sqlx::migrate!("./migrations")
        .run(pool)
        .await
        .map_err(|e| AppError::Internal(format!("Migration failed: {}", e)))?;
    Ok(())
}
