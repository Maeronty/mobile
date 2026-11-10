pub mod config;
pub mod db;
pub mod error;
pub mod handlers;
pub mod middleware;
pub mod models;
pub mod services;
pub mod state;

pub use config::Config;
pub use error::AppError;
pub use state::AppState;

use axum::{
    extract::DefaultBodyLimit,
    routing::{get, post, put},
    Router,
};
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;

pub fn create_app(state: AppState) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    Router::new()
        // Health routes
        .route("/api/health", get(handlers::health_check))
        .route("/health", get(handlers::health_check))
        // Auth & Account routes
        .route("/api/Account/register", post(handlers::auth::register))
        .route("/api/account/register", post(handlers::auth::register))
        .route("/api/auth/register", post(handlers::auth::register))
        .route("/api/Account/login", post(handlers::auth::login))
        .route("/api/account/login", post(handlers::auth::login))
        .route("/api/auth/login", post(handlers::auth::login))
        .route("/api/Account/profile", get(handlers::auth::get_profile))
        .route("/api/account/profile", get(handlers::auth::get_profile))
        .route(
            "/api/auth/profile",
            get(handlers::auth::get_profile).put(handlers::auth::update_profile),
        )
        .route(
            "/api/Account/update-profile",
            put(handlers::auth::update_profile),
        )
        .route(
            "/api/account/update-profile",
            put(handlers::auth::update_profile),
        )
        .route(
            "/api/Account/change-password",
            post(handlers::auth::change_password),
        )
        .route(
            "/api/account/change-password",
            post(handlers::auth::change_password),
        )
        .route(
            "/api/Account/upgrade-to-vip",
            post(handlers::auth::upgrade_to_vip),
        )
        .route(
            "/api/account/upgrade-to-vip",
            post(handlers::auth::upgrade_to_vip),
        )
        // Recipe & Catalog routes
        .route("/catalog", get(handlers::recipe::get_catalog))
        .route("/api/catalog", get(handlers::recipe::get_catalog))
        .route("/api/Recipes/catalog", get(handlers::recipe::get_catalog))
        .route("/api/recipes/catalog", get(handlers::recipe::get_catalog))
        .route("/api/Recipes", get(handlers::recipe::list_recipes))
        .route("/api/recipes", get(handlers::recipe::list_recipes))
        .route("/api/Recipes/search", get(handlers::recipe::search_recipes))
        .route("/api/recipes/search", get(handlers::recipe::search_recipes))
        .route(
            "/api/Recipes/search-by-ingredients",
            get(handlers::recipe::search_by_ingredients),
        )
        .route(
            "/api/recipes/search-by-ingredients",
            get(handlers::recipe::search_by_ingredients),
        )
        .route(
            "/api/Recipes/ingredients",
            get(handlers::recipe::get_ingredients),
        )
        .route(
            "/api/recipes/ingredients",
            get(handlers::recipe::get_ingredients),
        )
        // Danh sách món có phân trang cho Home / danh mục
        .route("/api/Recipes/page", get(handlers::feed::page))
        .route("/api/Recipes/categories", get(handlers::feed::categories))
        .route("/api/Recipes/featured", get(handlers::feed::featured))
        .route("/api/Recipes/stats", get(handlers::recipe::get_stats))
        .route("/api/recipes/stats", get(handlers::recipe::get_stats))
        // Favorites routes (Milestone M4)
        .route("/api/Recipes/favorites", get(handlers::favorite::get_favorites))
        .route("/api/recipes/favorites", get(handlers::favorite::get_favorites))
        .route(
            "/api/Recipes/sync-favorites",
            post(handlers::favorite::sync_favorites),
        )
        .route(
            "/api/recipes/sync-favorites",
            post(handlers::favorite::sync_favorites),
        )
        .route(
            "/api/Recipes/:id/favorite",
            post(handlers::favorite::toggle_favorite),
        )
        .route(
            "/api/recipes/:id/favorite",
            post(handlers::favorite::toggle_favorite),
        )
        .route("/api/Recipes/:id", get(handlers::recipe::get_recipe_by_id))
        .route("/api/recipes/:id", get(handlers::recipe::get_recipe_by_id))
        .route("/suggest", post(handlers::recipe::suggest))
        .route("/api/suggest", post(handlers::recipe::suggest))
        // Proxy ảnh cho Flutter Web (ảnh nguồn không có header CORS)
        .route("/api/image", get(handlers::image::proxy_image))
        // AI routes (Gemini + Spoonacular, cần đăng nhập). Ảnh base64 ≤ 3 MB gốc
        // ≈ 4 MB JSON, vượt giới hạn 2 MB mặc định của axum nên nới riêng route này.
        .route(
            "/api/Ai/recognize",
            post(handlers::ai::recognize).layer(DefaultBodyLimit::max(5 * 1024 * 1024)),
        )
        .route("/api/Ai/suggest", post(handlers::ai::suggest))
        // Pantry & Kitchen Bag routes (Milestone M5)
        .route(
            "/api/pantry",
            get(handlers::pantry::get_pantry)
                .post(handlers::pantry::add_pantry_item)
                .delete(handlers::pantry::delete_or_clear_pantry),
        )
        .route(
            "/api/Pantry",
            get(handlers::pantry::get_pantry)
                .post(handlers::pantry::add_pantry_item)
                .delete(handlers::pantry::delete_or_clear_pantry),
        )
        .route(
            "/api/kitchen-bag",
            get(handlers::pantry::get_pantry)
                .post(handlers::pantry::add_pantry_item)
                .delete(handlers::pantry::delete_or_clear_pantry),
        )
        .route(
            "/api/KitchenBag",
            get(handlers::pantry::get_pantry)
                .post(handlers::pantry::add_pantry_item)
                .delete(handlers::pantry::delete_or_clear_pantry),
        )
        .route(
            "/api/kitchenbag",
            get(handlers::pantry::get_pantry)
                .post(handlers::pantry::add_pantry_item)
                .delete(handlers::pantry::delete_or_clear_pantry),
        )
        .route(
            "/api/pantry/:id",
            put(handlers::pantry::update_pantry_item)
                .delete(handlers::pantry::delete_pantry_item_by_id),
        )
        .route(
            "/api/Pantry/:id",
            put(handlers::pantry::update_pantry_item)
                .delete(handlers::pantry::delete_pantry_item_by_id),
        )
        .route(
            "/api/kitchen-bag/:id",
            put(handlers::pantry::update_pantry_item)
                .delete(handlers::pantry::delete_pantry_item_by_id),
        )
        .route(
            "/api/KitchenBag/:id",
            put(handlers::pantry::update_pantry_item)
                .delete(handlers::pantry::delete_pantry_item_by_id),
        )
        .route(
            "/api/kitchenbag/:id",
            put(handlers::pantry::update_pantry_item)
                .delete(handlers::pantry::delete_pantry_item_by_id),
        )
        .route(
            "/api/pantry/suggest",
            get(handlers::pantry::suggest_from_pantry),
        )
        .route(
            "/api/kitchen-bag/suggest",
            get(handlers::pantry::suggest_from_pantry),
        )
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
