#[allow(dead_code)]
mod common;

use common::setup_test_pool;
use food_tip_be_rust::db;
use sqlx::{Row, SqlitePool};
use std::sync::Arc;
use uuid::Uuid;

/// Helper to create a user and return id
async fn insert_dummy_user(pool: &SqlitePool, username: &str, email: &str) -> i64 {
    let now = chrono::Utc::now().to_rfc3339();
    sqlx::query_scalar(
        r#"
        INSERT INTO users (username, email, password_hash, display_name, created_at, updated_at)
        VALUES (?, ?, 'hash123', 'Display Name', ?, ?)
        RETURNING id
        "#,
    )
    .bind(username)
    .bind(email)
    .bind(&now)
    .bind(&now)
    .fetch_one(pool)
    .await
    .expect("Failed to insert dummy user")
}

/// Helper to insert a recipe with custom author and return id
async fn insert_dummy_recipe(pool: &SqlitePool, id: i64, user_id: Option<i64>, title: &str) -> i64 {
    let now = chrono::Utc::now().to_rfc3339();
    sqlx::query_scalar(
        r#"
        INSERT INTO recipes (
            id, user_id, title, description, image_url, source, category,
            cook_time_minutes, servings, difficulty, average_rating, total_ratings,
            status, created_at, updated_at
        ) VALUES (?, ?, ?, 'Sample description', 'http://example.com/img.jpg', 'Self', 'Món chính', 30, 2, 'Dễ', 5.0, 1, 'Published', ?, ?)
        RETURNING id
        "#,
    )
    .bind(id)
    .bind(user_id)
    .bind(title)
    .bind(&now)
    .bind(&now)
    .fetch_one(pool)
    .await
    .expect("Failed to insert dummy recipe")
}

// ============================================================================
// 1. FOREIGN KEY CASCADING & ON DELETE SET NULL ADVERSARIAL STRESS TESTS
// ============================================================================

#[tokio::test]
async fn test_adversarial_fk_recipe_deletion_cascade() {
    let pool = setup_test_pool().await;

    let user_id = insert_dummy_user(&pool, "chef_cascade", "chef@example.com").await;
    let recipe_id = 90001i64;
    insert_dummy_recipe(&pool, recipe_id, Some(user_id), "Món nướng đặc biệt").await;

    // Add nutrition
    sqlx::query(
        r#"
        INSERT INTO recipe_nutritions (recipe_id, calories, protein_grams, fat_grams, carbs_grams, fiber_grams, sugar_grams, sodium_mg)
        VALUES (?, 350.0, 25.0, 10.0, 40.0, 5.0, 2.0, 500.0)
        "#,
    )
    .bind(recipe_id)
    .execute(&pool)
    .await
    .expect("Failed to insert nutrition");

    // Add ingredients
    for i in 1..=5 {
        sqlx::query(
            "INSERT INTO recipe_ingredients (recipe_id, name, amount, unit, sort_order) VALUES (?, ?, ?, 'g', ?)",
        )
        .bind(recipe_id)
        .bind(format!("Nguyên liệu {}", i))
        .bind(50.0 * (i as f64))
        .bind(i)
        .execute(&pool)
        .await
        .expect("Failed to insert ingredient");
    }

    // Add instructions
    for s in 1..=3 {
        sqlx::query(
            "INSERT INTO recipe_instructions (recipe_id, step_number, content) VALUES (?, ?, ?)",
        )
        .bind(recipe_id)
        .bind(s)
        .bind(format!("Bước thực hiện số {}: Chuẩn bị và nấu", s))
        .execute(&pool)
        .await
        .expect("Failed to insert instruction");
    }

    // Add favorite
    let now = chrono::Utc::now().to_rfc3339();
    sqlx::query("INSERT INTO user_favorites (user_id, recipe_id, created_at) VALUES (?, ?, ?)")
        .bind(user_id)
        .bind(recipe_id)
        .bind(&now)
        .execute(&pool)
        .await
        .expect("Failed to insert favorite");

    // Add pantry item for the user
    sqlx::query("INSERT INTO pantry_items (user_id, name, amount, unit, created_at, updated_at) VALUES (?, 'Gia vị', 100.0, 'g', ?, ?)")
        .bind(user_id)
        .bind(&now)
        .bind(&now)
        .execute(&pool)
        .await
        .expect("Failed to insert pantry item");

    // Assert rows exist prior to deletion
    let nut_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_nutritions WHERE recipe_id = ?")
        .bind(recipe_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(nut_count.0, 1);

    let ing_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_ingredients WHERE recipe_id = ?")
        .bind(recipe_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(ing_count.0, 5);

    let step_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_instructions WHERE recipe_id = ?")
        .bind(recipe_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(step_count.0, 3);

    let fav_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE recipe_id = ?")
        .bind(recipe_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(fav_count.0, 1);

    // ACT: Delete recipe
    sqlx::query("DELETE FROM recipes WHERE id = ?")
        .bind(recipe_id)
        .execute(&pool)
        .await
        .expect("Delete recipe failed");

    // VERIFY: All dependent recipe entities & favorites cascade-deleted
    let nut_after: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_nutritions WHERE recipe_id = ?")
        .bind(recipe_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(nut_after.0, 0, "Nutritions must cascade delete");

    let ing_after: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_ingredients WHERE recipe_id = ?")
        .bind(recipe_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(ing_after.0, 0, "Ingredients must cascade delete");

    let step_after: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_instructions WHERE recipe_id = ?")
        .bind(recipe_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(step_after.0, 0, "Instructions must cascade delete");

    let fav_after: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE recipe_id = ?")
        .bind(recipe_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(fav_after.0, 0, "User favorite must cascade delete when recipe deleted");

    // VERIFY: User and Pantry items remain intact!
    let user_remains: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(user_remains.0, 1, "User must NOT be deleted when recipe is deleted");

    let pantry_remains: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(pantry_remains.0, 1, "Pantry items must NOT be deleted when recipe is deleted");
}

#[tokio::test]
async fn test_adversarial_fk_user_deletion_set_null_and_cascade() {
    let pool = setup_test_pool().await;

    let user_a = insert_dummy_user(&pool, "user_author", "author@test.com").await;
    let user_b = insert_dummy_user(&pool, "user_fan", "fan@test.com").await;

    let recipe_id = 90002i64;
    insert_dummy_recipe(&pool, recipe_id, Some(user_a), "Món của User Author").await;

    // Both users favorite the recipe
    let now = chrono::Utc::now().to_rfc3339();
    sqlx::query("INSERT INTO user_favorites (user_id, recipe_id, created_at) VALUES (?, ?, ?)")
        .bind(user_a)
        .bind(recipe_id)
        .bind(&now)
        .execute(&pool)
        .await
        .unwrap();

    sqlx::query("INSERT INTO user_favorites (user_id, recipe_id, created_at) VALUES (?, ?, ?)")
        .bind(user_b)
        .bind(recipe_id)
        .bind(&now)
        .execute(&pool)
        .await
        .unwrap();

    // Both have pantry items
    sqlx::query("INSERT INTO pantry_items (user_id, name, amount, unit, created_at, updated_at) VALUES (?, 'Mắm', 1.0, 'chai', ?, ?)")
        .bind(user_a)
        .bind(&now)
        .bind(&now)
        .execute(&pool)
        .await
        .unwrap();

    sqlx::query("INSERT INTO pantry_items (user_id, name, amount, unit, created_at, updated_at) VALUES (?, 'Muối', 0.5, 'kg', ?, ?)")
        .bind(user_b)
        .bind(&now)
        .bind(&now)
        .execute(&pool)
        .await
        .unwrap();

    // ACT: Delete user_a (the author of recipe_id)
    sqlx::query("DELETE FROM users WHERE id = ?")
        .bind(user_a)
        .execute(&pool)
        .await
        .expect("Delete user_a failed");

    // 1. Verify user_a's pantry items were cascade deleted
    let pantry_a_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_a)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(pantry_a_count.0, 0, "User A pantry items must be cascade deleted");

    // 2. Verify user_b's pantry items are STILL intact
    let pantry_b_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_b)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(pantry_b_count.0, 1, "User B pantry items must remain untouched");

    // 3. Verify user_a's favorite was cascade deleted
    let fav_a_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE user_id = ?")
        .bind(user_a)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(fav_a_count.0, 0, "User A favorite must be cascade deleted");

    // 4. Verify user_b's favorite on recipe_id is STILL intact
    let fav_b_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = ?")
        .bind(user_b)
        .bind(recipe_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(fav_b_count.0, 1, "User B favorite must remain intact");

    // 5. CRITICAL: Verify recipe_id STILL EXISTS, but its user_id has been SET TO NULL!
    let recipe_row = sqlx::query("SELECT id, user_id, title FROM recipes WHERE id = ?")
        .bind(recipe_id)
        .fetch_one(&pool)
        .await
        .expect("Recipe must still exist after author deletion!");

    let author_col: Option<i64> = recipe_row.get("user_id");
    assert!(author_col.is_none(), "Recipe user_id must be NULL following author deletion (ON DELETE SET NULL)");
}

// ============================================================================
// 2. FOREIGN KEY ENFORCEMENT ON INVALID REFERENCES
// ============================================================================

#[tokio::test]
async fn test_adversarial_fk_rejection_on_invalid_parents() {
    let pool = setup_test_pool().await;
    let non_existent_id = 8888888i64;
    let now = chrono::Utc::now().to_rfc3339();

    // 1. Cannot insert recipe with non-existent user_id
    let res = sqlx::query(
        "INSERT INTO recipes (id, user_id, title, category, created_at, updated_at) VALUES (77701, ?, 'Invalid User Recipe', 'Test', ?, ?)",
    )
    .bind(non_existent_id)
    .bind(&now)
    .bind(&now)
    .execute(&pool)
    .await;
    assert!(res.is_err(), "Must reject recipe with non-existent user_id");

    // 2. Cannot insert nutrition with non-existent recipe_id
    let res = sqlx::query(
        "INSERT INTO recipe_nutritions (recipe_id, calories) VALUES (?, 200.0)",
    )
    .bind(non_existent_id)
    .execute(&pool)
    .await;
    assert!(res.is_err(), "Must reject recipe_nutritions with non-existent recipe_id");

    // 3. Cannot insert ingredients with non-existent recipe_id
    let res = sqlx::query(
        "INSERT INTO recipe_ingredients (recipe_id, name, amount, unit) VALUES (?, 'Ghost Salt', 1.0, 'tsp')",
    )
    .bind(non_existent_id)
    .execute(&pool)
    .await;
    assert!(res.is_err(), "Must reject recipe_ingredients with non-existent recipe_id");

    // 4. Cannot insert instructions with non-existent recipe_id
    let res = sqlx::query(
        "INSERT INTO recipe_instructions (recipe_id, step_number, content) VALUES (?, 1, 'Ghost Step')",
    )
    .bind(non_existent_id)
    .execute(&pool)
    .await;
    assert!(res.is_err(), "Must reject recipe_instructions with non-existent recipe_id");

    // 5. Cannot insert favorite with non-existent user_id
    let valid_user = insert_dummy_user(&pool, "valid_u", "valid_u@test.com").await;
    let valid_recipe = insert_dummy_recipe(&pool, 77702, None, "Valid Recipe").await;

    let res = sqlx::query(
        "INSERT INTO user_favorites (user_id, recipe_id, created_at) VALUES (?, ?, ?)",
    )
    .bind(non_existent_id)
    .bind(valid_recipe)
    .bind(&now)
    .execute(&pool)
    .await;
    assert!(res.is_err(), "Must reject user_favorites with non-existent user_id");

    // 6. Cannot insert favorite with non-existent recipe_id
    let res = sqlx::query(
        "INSERT INTO user_favorites (user_id, recipe_id, created_at) VALUES (?, ?, ?)",
    )
    .bind(valid_user)
    .bind(non_existent_id)
    .bind(&now)
    .execute(&pool)
    .await;
    assert!(res.is_err(), "Must reject user_favorites with non-existent recipe_id");

    // 7. Cannot insert pantry item with non-existent user_id
    let res = sqlx::query(
        "INSERT INTO pantry_items (user_id, name, created_at, updated_at) VALUES (?, 'Sugar', ?, ?)",
    )
    .bind(non_existent_id)
    .bind(&now)
    .bind(&now)
    .execute(&pool)
    .await;
    assert!(res.is_err(), "Must reject pantry_items with non-existent user_id");
}

// ============================================================================
// 3. CONSTRAINT ENFORCEMENT (UNIQUE, NOT NULL, PRIMARY KEY)
// ============================================================================

#[tokio::test]
async fn test_adversarial_unique_and_not_null_constraints() {
    let pool = setup_test_pool().await;
    let now = chrono::Utc::now().to_rfc3339();

    // 1. Unique username violation
    let _ = insert_dummy_user(&pool, "unique_user", "email1@test.com").await;
    let dup_name_res = sqlx::query(
        "INSERT INTO users (username, email, password_hash, created_at, updated_at) VALUES ('unique_user', 'different_email@test.com', 'h', ?, ?)",
    )
    .bind(&now)
    .bind(&now)
    .execute(&pool)
    .await;
    assert!(dup_name_res.is_err(), "Duplicate username must be rejected");

    // 2. Unique email violation
    let dup_email_res = sqlx::query(
        "INSERT INTO users (username, email, password_hash, created_at, updated_at) VALUES ('different_user', 'email1@test.com', 'h', ?, ?)",
    )
    .bind(&now)
    .bind(&now)
    .execute(&pool)
    .await;
    assert!(dup_email_res.is_err(), "Duplicate email must be rejected");

    // 3. Primary key composite unique violation in user_favorites
    let user = insert_dummy_user(&pool, "fav_tester", "fav@test.com").await;
    let recipe = insert_dummy_recipe(&pool, 77703, None, "Fav Recipe").await;
    let _ = sqlx::query("INSERT INTO user_favorites (user_id, recipe_id, created_at) VALUES (?, ?, ?)")
        .bind(user)
        .bind(recipe)
        .bind(&now)
        .execute(&pool)
        .await
        .unwrap();

    let dup_fav = sqlx::query("INSERT INTO user_favorites (user_id, recipe_id, created_at) VALUES (?, ?, ?)")
        .bind(user)
        .bind(recipe)
        .bind(&now)
        .execute(&pool)
        .await;
    assert!(dup_fav.is_err(), "Duplicate (user_id, recipe_id) favorite must violate composite primary key");

    // 4. NOT NULL constraint rejections across all tables
    // Users table
    let null_user_name = sqlx::query("INSERT INTO users (username, email, password_hash, created_at, updated_at) VALUES (NULL, 'e@test.com', 'h', ?, ?)")
        .bind(&now)
        .bind(&now)
        .execute(&pool)
        .await;
    assert!(null_user_name.is_err(), "users.username NULL must fail");

    let null_user_email = sqlx::query("INSERT INTO users (username, email, password_hash, created_at, updated_at) VALUES ('user_null_mail', NULL, 'h', ?, ?)")
        .bind(&now)
        .bind(&now)
        .execute(&pool)
        .await;
    assert!(null_user_email.is_err(), "users.email NULL must fail");

    let null_user_hash = sqlx::query("INSERT INTO users (username, email, password_hash, created_at, updated_at) VALUES ('user_null_hash', 'enh@test.com', NULL, ?, ?)")
        .bind(&now)
        .bind(&now)
        .execute(&pool)
        .await;
    assert!(null_user_hash.is_err(), "users.password_hash NULL must fail");

    // Recipes table
    let null_recipe_title = sqlx::query("INSERT INTO recipes (id, title, category, created_at, updated_at) VALUES (77704, NULL, 'Cat', ?, ?)")
        .bind(&now)
        .bind(&now)
        .execute(&pool)
        .await;
    assert!(null_recipe_title.is_err(), "recipes.title NULL must fail");

    let null_recipe_cat = sqlx::query("INSERT INTO recipes (id, title, category, created_at, updated_at) VALUES (77705, 'Title', NULL, ?, ?)")
        .bind(&now)
        .bind(&now)
        .execute(&pool)
        .await;
    assert!(null_recipe_cat.is_err(), "recipes.category NULL must fail");

    // Recipe ingredients
    let null_ing_name = sqlx::query("INSERT INTO recipe_ingredients (recipe_id, name) VALUES (?, NULL)")
        .bind(recipe)
        .execute(&pool)
        .await;
    assert!(null_ing_name.is_err(), "recipe_ingredients.name NULL must fail");

    // Recipe instructions
    let null_inst_content = sqlx::query("INSERT INTO recipe_instructions (recipe_id, step_number, content) VALUES (?, 1, NULL)")
        .bind(recipe)
        .execute(&pool)
        .await;
    assert!(null_inst_content.is_err(), "recipe_instructions.content NULL must fail");

    // Pantry items
    let null_pantry_name = sqlx::query("INSERT INTO pantry_items (user_id, name, created_at, updated_at) VALUES (?, NULL, ?, ?)")
        .bind(user)
        .bind(&now)
        .bind(&now)
        .execute(&pool)
        .await;
    assert!(null_pantry_name.is_err(), "pantry_items.name NULL must fail");
}

// ============================================================================
// 4. MIGRATION SEQUENTIAL IDEMPOTENCE & REPLAY STRESS
// ============================================================================

#[tokio::test]
async fn test_adversarial_migration_idempotence_replay() {
    let unique_db_name = format!("file:memdb_mig_{}?mode=memory&cache=shared", Uuid::new_v4());
    let pool = db::create_pool(&unique_db_name)
        .await
        .expect("Failed to create in-memory sqlite pool");

    // Run migration 5 times sequentially on the same database
    for i in 1..=5 {
        let mig_res = db::run_migrations(&pool).await;
        assert!(
            mig_res.is_ok(),
            "Migration execution #{i} failed: {:?}",
            mig_res.err()
        );
    }

    // Verify _sqlx_migrations has exactly 1 applied version
    let migration_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM _sqlx_migrations")
        .fetch_one(&pool)
        .await
        .expect("Failed to read _sqlx_migrations");

    assert_eq!(
        migration_count.0, 1,
        "Only 1 migration file should be recorded in _sqlx_migrations, got {}",
        migration_count.0
    );

    // Verify table structure is pristine and accessible
    let tables: Vec<(String,)> = sqlx::query_as(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_sqlx_%' ORDER BY name"
    )
    .fetch_all(&pool)
    .await
    .unwrap();

    let table_names: Vec<String> = tables.into_iter().map(|(n,)| n).collect();
    let expected = vec![
        "pantry_items",
        "recipe_ingredients",
        "recipe_instructions",
        "recipe_nutritions",
        "recipes",
        "user_favorites",
        "users",
    ];
    assert_eq!(table_names, expected, "All tables must exist in expected schema");
}

// ============================================================================
// 5. SEED RESILIENCE, IDEMPOTENCE & CONCURRENT EXECUTION STRESS
// ============================================================================

#[tokio::test]
async fn test_adversarial_seed_sequential_multiple_calls() {
    let pool = setup_test_pool().await;

    // Call seed sequentially 5 times
    for i in 1..=5 {
        let count = db::seed_database(&pool)
            .await
            .unwrap_or_else(|e| panic!("Sequential seed #{} failed: {:?}", i, e));
        assert_eq!(count, 8, "Seed must report 8 recipes on call #{}", i);
    }

    // Exactly 8 recipes should be in DB, never duplicates
    let recipe_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(recipe_count.0, 8, "Expected exactly 8 seeded recipes");

    let nut_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_nutritions")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(nut_count.0, 8, "Expected exactly 8 recipe nutritions");

    let ing_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_ingredients")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(ing_count.0 >= 40, "Expected at least 40 ingredients");
}

#[tokio::test]
async fn test_adversarial_seed_concurrent_on_already_seeded_db() {
    let pool = setup_test_pool().await;
    // Initial seed
    let count = db::seed_database(&pool).await.expect("Initial seed failed");
    assert_eq!(count, 8);

    // Now fire 10 concurrent seed tasks on the seeded db
    let pool_arc = Arc::new(pool);
    let mut handles = Vec::new();
    for _ in 0..10 {
        let p = Arc::clone(&pool_arc);
        handles.push(tokio::spawn(async move {
            db::seed_database(&p).await
        }));
    }

    for h in handles {
        let res = h.await.expect("Join error");
        assert_eq!(res.unwrap(), 8);
    }

    let final_recipe_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(pool_arc.as_ref())
        .await
        .unwrap();
    assert_eq!(final_recipe_count.0, 8);
}

#[tokio::test]
async fn test_adversarial_seed_concurrency_race_condition_on_empty_db() {
    let pool = setup_test_pool().await;
    let pool_arc = Arc::new(pool);

    // Fire 5 concurrent seed tasks simultaneously on an initially EMPTY db
    let mut handles = Vec::new();
    for _ in 0..5 {
        let p = Arc::clone(&pool_arc);
        handles.push(tokio::spawn(async move {
            db::seed_database(&p).await
        }));
    }

    let mut successes = 0;
    let mut unique_constraint_errors = 0;
    for h in handles {
        let res = h.await.expect("Join error");
        match res {
            Ok(count) => {
                assert_eq!(count, 8);
                successes += 1;
            }
            Err(e) => {
                let err_str = e.to_string();
                if err_str.contains("UNIQUE constraint failed") {
                    unique_constraint_errors += 1;
                } else {
                    panic!("Unexpected error from concurrent seed: {}", err_str);
                }
            }
        }
    }

    // At least one task must succeed
    assert!(successes >= 1, "At least one seed task must succeed");
    
    // Exactly 8 recipes in the end regardless of race conditions
    let recipe_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(pool_arc.as_ref())
        .await
        .unwrap();
    assert_eq!(recipe_count.0, 8, "Expected exactly 8 seeded recipes despite concurrency");

    println!(
        "Concurrent seed race condition results on empty DB: {} successes, {} unique constraint collisions",
        successes, unique_constraint_errors
    );
}

// ============================================================================
// 6. PRAGMA WAL MODE & BUSY TIMEOUT VERIFICATION ON FILE DATABASE
// ============================================================================

#[tokio::test]
async fn test_adversarial_file_db_wal_mode_and_pragmas() {
    let temp_dir = std::env::temp_dir();
    let db_path = temp_dir.join(format!("food_tip_adv_test_{}.db", Uuid::new_v4()));
    let db_path_str = db_path.to_str().unwrap().replace('\\', "/");
    let db_url = format!("sqlite://{}", db_path_str);

    let pool = db::create_pool(&db_url)
        .await
        .expect("Failed to create file-based sqlite pool");

    db::run_migrations(&pool)
        .await
        .expect("Failed to run migrations on file db");

    // Verify journal mode is WAL
    let journal_mode: (String,) = sqlx::query_as("PRAGMA journal_mode")
        .fetch_one(&pool)
        .await
        .expect("Failed to query journal_mode");
    assert_eq!(
        journal_mode.0.to_lowercase(),
        "wal",
        "File-based SQLite database must use WAL mode"
    );

    // Verify foreign_keys is enabled (1)
    let foreign_keys: (i64,) = sqlx::query_as("PRAGMA foreign_keys")
        .fetch_one(&pool)
        .await
        .expect("Failed to query foreign_keys");
    assert_eq!(
        foreign_keys.0, 1,
        "foreign_keys pragma must be active (1)"
    );

    // Verify busy_timeout is 5000ms
    let busy_timeout: (i64,) = sqlx::query_as("PRAGMA busy_timeout")
        .fetch_one(&pool)
        .await
        .expect("Failed to query busy_timeout");
    assert_eq!(
        busy_timeout.0, 5000,
        "busy_timeout must be configured to 5000ms"
    );

    // Close pool and clean up files
    pool.close().await;
    let _ = std::fs::remove_file(&db_path);
    let _ = std::fs::remove_file(format!("{}-wal", db_path_str));
    let _ = std::fs::remove_file(format!("{}-shm", db_path_str));
}

// ============================================================================
// 7. EXTREME VALUES & UTF-8 SQL SPECIAL CHARACTERS STRESS TEST
// ============================================================================

#[tokio::test]
async fn test_adversarial_utf8_and_special_character_resilience() {
    let pool = setup_test_pool().await;
    let now = chrono::Utc::now().to_rfc3339();

    // Adversarial titles with quotes, semicolons, emoji, and Vietnamese accents
    let malicious_title = "Phở bò đặc biệt ' OR 1=1; DROP TABLE users; -- 🍲 🍜 🎉";
    let long_description = "A".repeat(5000); // 5000 chars

    let recipe_id = 99999i64;
    sqlx::query(
        r#"
        INSERT INTO recipes (
            id, user_id, title, description, category, cook_time_minutes, servings,
            difficulty, average_rating, total_ratings, status, created_at, updated_at
        ) VALUES (?, NULL, ?, ?, 'Đặc sản', 45, 4, 'Trung bình', 4.95, 100, 'Published', ?, ?)
        "#,
    )
    .bind(recipe_id)
    .bind(malicious_title)
    .bind(&long_description)
    .bind(&now)
    .bind(&now)
    .execute(&pool)
    .await
    .expect("Parameterized query must safely insert special characters and long descriptions");

    // Query back and assert exact content matches
    let row: (String, Option<String>) = sqlx::query_as("SELECT title, description FROM recipes WHERE id = ?")
        .bind(recipe_id)
        .fetch_one(&pool)
        .await
        .unwrap();

    assert_eq!(row.0, malicious_title);
    assert_eq!(row.1.unwrap(), long_description);

    // Verify users table was not dropped or affected
    let user_table_exists: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'users'",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(user_table_exists.0, 1, "Users table must remain intact");
}
