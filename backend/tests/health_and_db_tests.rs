mod common;

use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use common::{setup_test_app, setup_test_pool};
use food_tip_be_rust::db;
use http_body_util::BodyExt;
use serde_json::Value;
use tower::ServiceExt;

#[tokio::test]
async fn test_auto_migrations_create_all_tables() {
    let pool = setup_test_pool().await;

    // Verify all required tables exist in sqlite_master
    let expected_tables = vec![
        "users",
        "recipes",
        "recipe_nutritions",
        "recipe_ingredients",
        "recipe_instructions",
        "user_favorites",
        "pantry_items",
    ];

    for table in expected_tables {
        let count: (i64,) = sqlx::query_as(
            "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?",
        )
        .bind(table)
        .fetch_one(&pool)
        .await
        .expect("Failed to query sqlite_master");

        assert_eq!(
            count.0, 1,
            "Table '{}' was not created by migrations",
            table
        );
    }
}

#[tokio::test]
async fn test_health_check_endpoints() {
    let (app, _pool) = setup_test_app().await;

    // 1. Test GET /api/health
    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/health")
                .method("GET")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .expect("Failed to execute request");

    assert_eq!(response.status(), StatusCode::OK);
    let bytes = response
        .into_body()
        .collect()
        .await
        .unwrap()
        .to_bytes();
    let json: Value = serde_json::from_slice(&bytes).unwrap();
    assert_eq!(json["status"], "ok");
    assert_eq!(json["database"], "connected");

    // 2. Test GET /health alias
    let response_alias = app
        .oneshot(
            Request::builder()
                .uri("/health")
                .method("GET")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .expect("Failed to execute request");

    assert_eq!(response_alias.status(), StatusCode::OK);
    let bytes_alias = response_alias
        .into_body()
        .collect()
        .await
        .unwrap()
        .to_bytes();
    let json_alias: Value = serde_json::from_slice(&bytes_alias).unwrap();
    assert_eq!(json_alias["status"], "ok");
    assert_eq!(json_alias["database"], "connected");
}

#[tokio::test]
async fn test_database_seeding_and_idempotence() {
    let pool = setup_test_pool().await;

    // Initially recipes should be empty
    let initial_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(initial_count.0, 0);

    // Run first seed
    let seeded = db::seed_database(&pool).await.expect("Seeding failed");
    assert_eq!(seeded, 8, "Expected 8 canonical recipes to be seeded");

    // Verify row counts across all related tables
    let recipe_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(recipe_count.0, 8);

    let nutrition_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_nutritions")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(nutrition_count.0, 8);

    let ingredients_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_ingredients")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(
        ingredients_count.0 >= 40,
        "Expected multiple ingredients across 8 recipes, got {}",
        ingredients_count.0
    );

    let instructions_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_instructions")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(
        instructions_count.0 >= 20,
        "Expected multiple steps across 8 recipes, got {}",
        instructions_count.0
    );

    // Verify canonical recipe with id 715415 exists
    let title: (String,) = sqlx::query_as("SELECT title FROM recipes WHERE id = 715415")
        .fetch_one(&pool)
        .await
        .expect("Canonical recipe 715415 not found");
    assert!(title.0.contains("Súp Đậu Lăng Đỏ"));

    // Verify idempotence: running seed again does not duplicate or fail
    let reseed = db::seed_database(&pool).await.expect("Reseed should succeed");
    assert_eq!(reseed, 8);

    let recipe_count_after: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(recipe_count_after.0, 8, "Recipe count changed after reseed");
}

#[tokio::test]
async fn test_foreign_key_cascades_and_constraints() {
    let pool = setup_test_pool().await;
    let _ = db::seed_database(&pool).await.expect("Seeding failed");

    // 1. Insert a test user
    let user_id: i64 = sqlx::query_scalar(
        r#"
        INSERT INTO users (username, email, password_hash, display_name, created_at, updated_at)
        VALUES ('testuser', 'testuser@example.com', '$argon2id$v=19$m=19456,t=2,p=1$fakehash', 'Test User', '2026-11-10T00:00:00Z', '2026-11-10T00:00:00Z')
        RETURNING id
        "#,
    )
    .fetch_one(&pool)
    .await
    .expect("Failed to insert user");

    // 2. Add user favorite for recipe 715415
    sqlx::query("INSERT INTO user_favorites (user_id, recipe_id, created_at) VALUES (?, ?, '2026-11-10T00:00:00Z')")
        .bind(user_id)
        .bind(715415i64)
        .execute(&pool)
        .await
        .expect("Failed to add favorite");

    // 3. Add pantry item for user
    sqlx::query("INSERT INTO pantry_items (user_id, name, amount, unit, created_at, updated_at) VALUES (?, 'Tỏi băm', 2.0, 'nhánh', '2026-11-10T00:00:00Z', '2026-11-10T00:00:00Z')")
        .bind(user_id)
        .execute(&pool)
        .await
        .expect("Failed to add pantry item");

    // 4. Verify duplicate username fails UNIQUE constraint
    let dup_user_result = sqlx::query(
        "INSERT INTO users (username, email, password_hash, created_at, updated_at) VALUES ('testuser', 'another@example.com', 'hash', '2026-11-10T00:00:00Z', '2026-11-10T00:00:00Z')",
    )
    .execute(&pool)
    .await;
    assert!(dup_user_result.is_err(), "Duplicate username should fail UNIQUE constraint");

    // 5. Delete recipe 715415 and verify cascade deletion of nutritions, ingredients, instructions, and favorites
    sqlx::query("DELETE FROM recipes WHERE id = 715415")
        .execute(&pool)
        .await
        .expect("Failed to delete recipe");

    let nut_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_nutritions WHERE recipe_id = 715415")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(nut_count.0, 0, "Recipe nutritions should cascade delete");

    let ing_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_ingredients WHERE recipe_id = 715415")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(ing_count.0, 0, "Recipe ingredients should cascade delete");

    let fav_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE recipe_id = 715415")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(fav_count.0, 0, "User favorite should cascade delete when recipe is deleted");

    // 6. Delete user and verify cascade deletion of pantry items
    sqlx::query("DELETE FROM users WHERE id = ?")
        .bind(user_id)
        .execute(&pool)
        .await
        .expect("Failed to delete user");

    let pantry_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(pantry_count.0, 0, "Pantry items should cascade delete when user is deleted");
}
