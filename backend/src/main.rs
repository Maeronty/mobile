use food_tip_be_rust::{config::Config, create_app, db, state::AppState};
use std::net::SocketAddr;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "food_tip_be_rust=debug,tower_http=debug,axum=trace".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let config = Config::load();
    tracing::info!("Starting Food Tip System Backend (Rust) on port {}", config.port);

    let pool = db::create_pool(&config.database_url).await?;
    tracing::info!("SQLite database pool initialized at {}", config.database_url);

    db::run_migrations(&pool).await?;
    tracing::info!("Database migrations executed successfully.");

    db::seed_database(&pool).await?;

    let state = AppState::new(pool, config.clone());
    let app = create_app(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], config.port));
    tracing::info!("Listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
