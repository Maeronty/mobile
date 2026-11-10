use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use food_tip_be_rust::{
    config::Config,
    create_app,
    db::{create_pool, run_migrations, seed_database},
    state::AppState,
};
use http_body_util::BodyExt;
use serde_json::Value;
use sqlx::{Row, SqlitePool};
use std::{path::PathBuf, time::Instant};
use tower::ServiceExt;
use uuid::Uuid;

/// Helper to initialize a real file-backed SQLite database with WAL mode enabled.
struct TestWalDb {
    pub db_url: String,
    pub file_path: PathBuf,
    pub pool: SqlitePool,
}

impl TestWalDb {
    async fn new(seed: bool) -> Self {
        let unique_name = format!("test_wal_{}.db", Uuid::new_v4());
        let target_dir = PathBuf::from("target").join("test_dbs");
        std::fs::create_dir_all(&target_dir).expect("Failed to create target/test_dbs directory");
        let file_path = target_dir.join(unique_name);

        let normalized_path = file_path.to_str().unwrap().replace('\\', "/");
        let db_url = format!("sqlite://{}?mode=rwc", normalized_path);

        let pool = create_pool(&db_url)
            .await
            .unwrap_or_else(|e| panic!("Failed to create pool for {}: {:?}", db_url, e));

        run_migrations(&pool)
            .await
            .expect("Failed to run migrations on test WAL DB");

        if seed {
            seed_database(&pool)
                .await
                .expect("Failed to seed test WAL DB");
        }

        Self {
            db_url,
            file_path,
            pool,
        }
    }

    async fn cleanup(self) {
        self.pool.close().await;
        // Small delay to ensure OS file handles close
        tokio::time::sleep(std::time::Duration::from_millis(50)).await;

        let _ = std::fs::remove_file(&self.file_path);
        let wal = format!("{}-wal", self.file_path.display());
        let _ = std::fs::remove_file(wal);
        let shm = format!("{}-shm", self.file_path.display());
        let _ = std::fs::remove_file(shm);
    }
}

/// Helper to build an Axum AppState and router with a real WAL database
async fn setup_wal_app(test_db: &TestWalDb) -> axum::Router {
    let config = Config {
        port: 8787,
        database_url: test_db.db_url.clone(),
        jwt_secret: "AdversarialStressTestSecretKey2026!".to_string(),
        jwt_expiration_hours: 2,
    };
    let state = AppState::new(test_db.pool.clone(), config);
    create_app(state)
}

// -----------------------------------------------------------------------------
// Test 1: Verify SQLite WAL Mode and Core Pragmas
// -----------------------------------------------------------------------------
#[tokio::test]
async fn test_empirically_verify_sqlite_wal_pragmas() {
    let test_db = TestWalDb::new(false).await;

    // 1. Check journal_mode == "wal"
    let journal_mode: (String,) = sqlx::query_as("PRAGMA journal_mode;")
        .fetch_one(&test_db.pool)
        .await
        .expect("PRAGMA journal_mode query failed");
    assert_eq!(
        journal_mode.0.to_lowercase(),
        "wal",
        "SQLite journal_mode must be WAL for concurrent access"
    );

    // 2. Check busy_timeout == 5000 (5 seconds)
    let busy_timeout: (i64,) = sqlx::query_as("PRAGMA busy_timeout;")
        .fetch_one(&test_db.pool)
        .await
        .expect("PRAGMA busy_timeout query failed");
    assert_eq!(
        busy_timeout.0, 5000,
        "PRAGMA busy_timeout must be configured to 5000ms"
    );

    // 3. Check foreign_keys == 1 (enabled)
    let foreign_keys: (i64,) = sqlx::query_as("PRAGMA foreign_keys;")
        .fetch_one(&test_db.pool)
        .await
        .expect("PRAGMA foreign_keys query failed");
    assert_eq!(
        foreign_keys.0, 1,
        "PRAGMA foreign_keys must be enabled (1) for relational cascades"
    );

    test_db.cleanup().await;
}

// -----------------------------------------------------------------------------
// Test 2: Adversarial Concurrent Read/Write Stress (100 Concurrent Tasks)
// -----------------------------------------------------------------------------
#[tokio::test]
async fn test_adversarial_concurrent_read_write_stress_100_tasks() {
    let test_db = TestWalDb::new(true).await;
    let pool = test_db.pool.clone();

    // Insert anchor user for foreign keys
    let user_id: i64 = sqlx::query_scalar(
        r#"
        INSERT INTO users (username, email, password_hash, display_name, created_at, updated_at)
        VALUES ('stress_user', 'stress@test.com', 'dummy_hash', 'Stress User', '2026-11-10T00:00:00Z', '2026-11-10T00:00:00Z')
        RETURNING id
        "#,
    )
    .fetch_one(&pool)
    .await
    .expect("Failed to insert anchor user");

    let initial_servings: (i64,) = sqlx::query_as("SELECT servings FROM recipes WHERE id = 715415")
        .fetch_one(&pool)
        .await
        .expect("Failed to fetch initial recipe servings");

    let total_tasks = 100;
    let mut handles = Vec::with_capacity(total_tasks);
    let start_time = Instant::now();

    // 100 tasks partitioned:
    // - Tasks 0..30 (30): Writes - insert pantry items
    // - Tasks 30..50 (20): Writes - update recipe servings
    // - Tasks 50..75 (25): Reads - query recipes
    // - Tasks 75..100 (25): Reads - query pantry count & user info
    for task_id in 0..total_tasks {
        let pool_clone = pool.clone();

        if task_id < 30 {
            // Task: Pantry Item Insertion (Write)
            let handle = tokio::spawn(async move {
                let item_name = format!("Stress_Ingredient_{}", task_id);
                sqlx::query(
                    r#"
                    INSERT INTO pantry_items (user_id, name, amount, unit, created_at, updated_at)
                    VALUES (?, ?, ?, 'gam', '2026-11-10T00:00:00Z', '2026-11-10T00:00:00Z')
                    "#,
                )
                .bind(user_id)
                .bind(&item_name)
                .bind(task_id as f64 + 1.0)
                .execute(&pool_clone)
                .await
                .map(|_| ())
                .map_err(|e| format!("Write pantry item task {} failed: {:?}", task_id, e))
            });
            handles.push(handle);
        } else if task_id < 50 {
            // Task: Recipe Update (Write)
            let handle = tokio::spawn(async move {
                sqlx::query("UPDATE recipes SET servings = servings + 1 WHERE id = 715415")
                    .execute(&pool_clone)
                    .await
                    .map(|_| ())
                    .map_err(|e| format!("Update recipe task {} failed: {:?}", task_id, e))
            });
            handles.push(handle);
        } else if task_id < 75 {
            // Task: Recipe Read (Read)
            let handle = tokio::spawn(async move {
                let row = sqlx::query("SELECT id, title, servings FROM recipes WHERE id = 715415")
                    .fetch_one(&pool_clone)
                    .await
                    .map_err(|e| format!("Read recipe task {} failed: {:?}", task_id, e))?;

                let title: String = row.get("title");
                assert!(!title.is_empty(), "Recipe title should not be empty");
                Ok::<(), String>(())
            });
            handles.push(handle);
        } else {
            // Task: Pantry Count & Health Ping Read (Read)
            let handle = tokio::spawn(async move {
                let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
                    .bind(user_id)
                    .fetch_one(&pool_clone)
                    .await
                    .map_err(|e| format!("Read pantry count task {} failed: {:?}", task_id, e))?;

                // Also execute quick connectivity check
                let ping: (i64,) = sqlx::query_as("SELECT 1")
                    .fetch_one(&pool_clone)
                    .await
                    .map_err(|e| format!("Ping DB task {} failed: {:?}", task_id, e))?;

                assert_eq!(ping.0, 1);
                assert!(count.0 >= 0);
                Ok::<(), String>(())
            });
            handles.push(handle);
        }
    }

    // Await all 100 tasks and collect any errors
    let mut failure_messages = Vec::new();
    for (i, handle) in handles.into_iter().enumerate() {
        match handle.await {
            Ok(result) => {
                if let Err(err_msg) = result {
                    failure_messages.push(err_msg);
                }
            }
            Err(panic_err) => {
                failure_messages.push(format!("Task {} panicked: {:?}", i, panic_err));
            }
        }
    }

    let elapsed = start_time.elapsed();
    println!(
        "Stress test completed 100 concurrent tasks in {:.2?} with {} errors",
        elapsed,
        failure_messages.len()
    );

    // Assert that NO tasks encountered SQLITE_BUSY or any database errors
    assert!(
        failure_messages.is_empty(),
        "Encountered {} errors in 100 concurrent tasks:\n{:#?}",
        failure_messages.len(),
        failure_messages
    );

    // Verify final state consistency
    let final_pantry_count: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
            .bind(user_id)
            .fetch_one(&pool)
            .await
            .expect("Failed to fetch final pantry count");
    assert_eq!(
        final_pantry_count.0, 30,
        "All 30 concurrent pantry item writes must have succeeded"
    );

    // Canonical recipe initial servings was 8; 20 updates incremented it by 20 -> 28
    let final_servings: (i64,) = sqlx::query_as("SELECT servings FROM recipes WHERE id = 715415")
        .fetch_one(&pool)
        .await
        .expect("Failed to fetch updated recipe servings");
    assert_eq!(
        final_servings.0,
        initial_servings.0 + 20,
        "All 20 concurrent recipe update writes must have succeeded"
    );

    test_db.cleanup().await;
}

// -----------------------------------------------------------------------------
// Test 3: Health Check Endpoint Under High Concurrent Load (60 Requests)
// -----------------------------------------------------------------------------
#[tokio::test]
async fn test_adversarial_health_check_concurrent_load_60_requests() {
    let test_db = TestWalDb::new(true).await;
    let app = setup_wal_app(&test_db).await;

    let total_requests = 60;
    let mut handles = Vec::with_capacity(total_requests);
    let start_time = Instant::now();

    for req_id in 0..total_requests {
        let app_clone = app.clone();
        let handle = tokio::spawn(async move {
            let request = Request::builder()
                .uri("/api/health")
                .method("GET")
                .body(Body::empty())
                .unwrap();

            let response = app_clone
                .oneshot(request)
                .await
                .map_err(|e| format!("Req {} Tower oneshot error: {:?}", req_id, e))?;

            let status = response.status();
            let body_bytes = response
                .into_body()
                .collect()
                .await
                .map_err(|e| format!("Req {} body collect error: {:?}", req_id, e))?
                .to_bytes();

            let json: Value = serde_json::from_slice(&body_bytes)
                .map_err(|e| format!("Req {} JSON parse error: {:?}", req_id, e))?;

            Ok::<(StatusCode, Value), String>((status, json))
        });
        handles.push(handle);
    }

    let mut successful_responses = 0;
    let mut failure_messages = Vec::new();

    for (idx, handle) in handles.into_iter().enumerate() {
        match handle.await {
            Ok(result) => match result {
                Ok((status, json)) => {
                    assert_eq!(
                        status,
                        StatusCode::OK,
                        "Health check request {} returned non-200: {}",
                        idx,
                        status
                    );
                    assert_eq!(
                        json["status"], "ok",
                        "Expected status=ok, got: {:?}",
                        json
                    );
                    assert_eq!(
                        json["database"], "connected",
                        "Expected database=connected, got: {:?}",
                        json
                    );
                    successful_responses += 1;
                }
                Err(err_msg) => failure_messages.push(err_msg),
            },
            Err(panic_err) => {
                failure_messages.push(format!("Request {} panicked: {:?}", idx, panic_err));
            }
        }
    }

    let elapsed = start_time.elapsed();
    println!(
        "Concurrent health checks: {}/{} succeeded in {:.2?}",
        successful_responses, total_requests, elapsed
    );

    assert_eq!(
        successful_responses, total_requests,
        "Expected 100% (60/60) of concurrent health checks to succeed. Failures: {:#?}",
        failure_messages
    );

    test_db.cleanup().await;
}

// -----------------------------------------------------------------------------
// Test 4: Mixed Adversarial Stress: Health Check Under Simultaneous Heavy Write Bursts
// -----------------------------------------------------------------------------
#[tokio::test]
async fn test_adversarial_mixed_health_requests_under_heavy_write_burst() {
    let test_db = TestWalDb::new(true).await;
    let app = setup_wal_app(&test_db).await;
    let pool = test_db.pool.clone();

    // Insert user for write tasks
    let user_id: i64 = sqlx::query_scalar(
        r#"
        INSERT INTO users (username, email, password_hash, display_name, created_at, updated_at)
        VALUES ('mixed_stress_user', 'mixed@test.com', 'dummy_hash', 'Mixed User', '2026-11-10T00:00:00Z', '2026-11-10T00:00:00Z')
        RETURNING id
        "#,
    )
    .fetch_one(&pool)
    .await
    .expect("Failed to insert user for mixed stress");

    let num_writes = 40;
    let num_health = 40;
    let total_tasks = num_writes + num_health;
    let mut handles = Vec::with_capacity(total_tasks);

    // Spawn 40 write tasks and 40 health check HTTP requests interleaved
    for i in 0..num_writes {
        // 1. Heavy Write Task: Insert pantry item
        let pool_clone = pool.clone();
        let write_handle = tokio::spawn(async move {
            let item_name = format!("Burst_Pantry_Item_{}", i);
            sqlx::query(
                r#"
                INSERT INTO pantry_items (user_id, name, amount, unit, created_at, updated_at)
                VALUES (?, ?, 10.0, 'hop', '2026-11-10T00:00:00Z', '2026-11-10T00:00:00Z')
                "#,
            )
            .bind(user_id)
            .bind(&item_name)
            .execute(&pool_clone)
            .await
            .map(|_| ())
            .map_err(|e| format!("Write task {} failed: {:?}", i, e))
        });
        handles.push(write_handle);

        // 2. Health Check HTTP Task through Axum router
        let app_clone = app.clone();
        let health_handle = tokio::spawn(async move {
            let req = Request::builder()
                .uri("/api/health")
                .method("GET")
                .body(Body::empty())
                .unwrap();

            let resp = app_clone
                .oneshot(req)
                .await
                .map_err(|e| format!("Health req {} oneshot failed: {:?}", i, e))?;

            assert_eq!(resp.status(), StatusCode::OK);
            let bytes = resp.into_body().collect().await.unwrap().to_bytes();
            let json: Value = serde_json::from_slice(&bytes).unwrap();
            assert_eq!(json["status"], "ok");
            assert_eq!(json["database"], "connected");
            Ok::<(), String>(())
        });
        handles.push(health_handle);
    }

    let mut failures = Vec::new();
    for handle in handles {
        match handle.await {
            Ok(result) => {
                if let Err(e) = result {
                    failures.push(e);
                }
            }
            Err(panic_err) => {
                failures.push(format!("Task panicked: {:?}", panic_err));
            }
        }
    }

    assert!(
        failures.is_empty(),
        "Mixed stress test had {} failures:\n{:#?}",
        failures.len(),
        failures
    );

    // Verify all 40 writes persisted
    let final_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(final_count.0, 40);

    test_db.cleanup().await;
}

// -----------------------------------------------------------------------------
// Test 5: Adversarial Multi-Statement Transactions & Connection Pool Contention
// -----------------------------------------------------------------------------
#[tokio::test]
async fn test_adversarial_concurrent_transactions_and_isolation() {
    let test_db = TestWalDb::new(false).await;
    let pool = test_db.pool.clone();

    let concurrent_tx_count = 35;
    let mut handles = Vec::with_capacity(concurrent_tx_count);

    for i in 0..concurrent_tx_count {
        let pool_clone = pool.clone();
        let handle = tokio::spawn(async move {
            // Begin explicit transaction
            let mut tx = pool_clone
                .begin()
                .await
                .map_err(|e| format!("TX {} begin failed: {:?}", i, e))?;

            // 1. Create a distinct user in transaction
            let username = format!("tx_user_{}", i);
            let email = format!("tx_user_{}@example.com", i);
            let user_id: i64 = sqlx::query_scalar(
                r#"
                INSERT INTO users (username, email, password_hash, display_name, created_at, updated_at)
                VALUES (?, ?, 'dummy_hash', 'TX User', '2026-11-10T00:00:00Z', '2026-11-10T00:00:00Z')
                RETURNING id
                "#,
            )
            .bind(&username)
            .bind(&email)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| format!("TX {} insert user failed: {:?}", i, e))?;

            // 2. Insert pantry item for this user
            sqlx::query(
                r#"
                INSERT INTO pantry_items (user_id, name, amount, unit, created_at, updated_at)
                VALUES (?, 'TX Ingredient', 5.0, 'goi', '2026-11-10T00:00:00Z', '2026-11-10T00:00:00Z')
                "#,
            )
            .bind(user_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| format!("TX {} insert pantry failed: {:?}", i, e))?;

            // 3. Commit transaction
            tx.commit()
                .await
                .map_err(|e| format!("TX {} commit failed: {:?}", i, e))?;

            Ok::<(), String>(())
        });
        handles.push(handle);
    }

    let mut failures = Vec::new();
    for handle in handles {
        match handle.await {
            Ok(result) => {
                if let Err(e) = result {
                    failures.push(e);
                }
            }
            Err(panic_err) => {
                failures.push(format!("TX task panicked: {:?}", panic_err));
            }
        }
    }

    assert!(
        failures.is_empty(),
        "Concurrent transactions had {} failures:\n{:#?}",
        failures.len(),
        failures
    );

    // Verify all 35 users and 35 pantry items were committed
    let user_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE username LIKE 'tx_user_%'")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(user_count.0, 35);

    let pantry_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE name = 'TX Ingredient'")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(pantry_count.0, 35);

    test_db.cleanup().await;
}
