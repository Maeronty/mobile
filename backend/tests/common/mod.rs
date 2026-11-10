use axum::Router;
use food_tip_be_rust::{config::Config, create_app, db, state::AppState};
use sqlx::SqlitePool;
use uuid::Uuid;

#[allow(dead_code)]
pub async fn setup_test_pool() -> SqlitePool {
    let unique_db_name = format!("file:memdb_{}?mode=memory&cache=shared", Uuid::new_v4());
    let pool = db::create_pool(&unique_db_name)
        .await
        .expect("Failed to create in-memory sqlite pool");

    db::run_migrations(&pool)
        .await
        .expect("Failed to run migrations on test db");

    pool
}

#[allow(dead_code)]
pub async fn setup_test_app() -> (Router, SqlitePool) {
    let pool = setup_test_pool().await;
    let _ = db::seed_database(&pool).await;

    let config = Config {
        port: 8787,
        database_url: "sqlite::memory:".to_string(),
        jwt_secret: "TestSecretKeyForTestingJwtTokensOnly12345!".to_string(),
        jwt_expiration_hours: 2,
    };

    let state = AppState::new(pool.clone(), config);
    let app = create_app(state);

    (app, pool)
}
