mod common;

use axum::{
    body::Body,
    http::{header, Request, StatusCode},
    Router,
};
use common::setup_test_app;
use food_tip_be_rust::services::auth_service::generate_jwt;
use http_body_util::BodyExt;
use serde_json::{json, Value};
use sqlx::SqlitePool;
use std::sync::Arc;
use tokio::task::JoinSet;
use tower::ServiceExt;

const TEST_SECRET: &str = "TestSecretKeyForTestingJwtTokensOnly12345!";

async fn send_request(
    app: &Router,
    method: &str,
    uri: &str,
    token: Option<&str>,
    body: Option<Value>,
) -> (StatusCode, Value) {
    let mut builder = Request::builder()
        .method(method)
        .uri(uri)
        .header(header::CONTENT_TYPE, "application/json");

    if let Some(tok) = token {
        builder = builder.header(header::AUTHORIZATION, format!("Bearer {}", tok));
    }

    let body_bytes = match body {
        Some(val) => Body::from(serde_json::to_vec(&val).unwrap()),
        None => Body::empty(),
    };

    let response = app
        .clone()
        .oneshot(builder.body(body_bytes).unwrap())
        .await
        .expect("Failed to execute request");

    let status = response.status();
    let bytes = response.into_body().collect().await.unwrap().to_bytes();
    let json_val: Value = serde_json::from_slice(&bytes).unwrap_or(Value::Null);

    (status, json_val)
}

async fn create_test_user(pool: &SqlitePool, username: &str, email: &str) -> (i64, String) {
    let now = chrono::Utc::now().to_rfc3339();
    let res = sqlx::query(
        "INSERT INTO users (username, email, password_hash, display_name, is_active, role, created_at, updated_at) VALUES (?, ?, 'dummy_hash', ?, 1, 'User', ?, ?)"
    )
    .bind(username)
    .bind(email)
    .bind(username)
    .bind(&now)
    .bind(&now)
    .execute(pool)
    .await
    .unwrap();

    let user_id = res.last_insert_rowid();
    let token = generate_jwt(user_id, email, "User", TEST_SECRET, false, 2).unwrap();
    (user_id, token)
}

/// Scenario 1: Rapid concurrent toggle requests on the same recipe by the same user.
/// EMPIRICAL FINDING: Without transaction or conflict-safe handling, concurrent requests
/// cause SQLite error 1555 (UNIQUE constraint failed) returning 500 Internal Server Error.
#[tokio::test]
async fn test_adversarial_rapid_concurrent_toggles_single_recipe() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "race_user_1", "race1@bepviet.vn").await;
    let app = Arc::new(app);
    let token = Arc::new(token);

    let concurrent_requests = 16;
    let mut join_set = JoinSet::new();

    for _ in 0..concurrent_requests {
        let app_clone = Arc::clone(&app);
        let token_clone = Arc::clone(&token);
        join_set.spawn(async move {
            send_request(
                &app_clone,
                "POST",
                "/api/Recipes/715415/favorite",
                Some(&token_clone),
                None,
            )
            .await
        });
    }

    let mut results = Vec::new();
    while let Some(res) = join_set.join_next().await {
        results.push(res.unwrap());
    }

    // Inspect if any returned 500 INTERNAL_SERVER_ERROR
    let server_errors: Vec<_> = results
        .iter()
        .filter(|(s, _)| *s == StatusCode::INTERNAL_SERVER_ERROR)
        .collect();

    assert!(
        server_errors.is_empty(),
        "Concurrent toggles should NEVER cause 500 Internal Server Error! Got {} errors: {:?}",
        server_errors.len(),
        server_errors
    );

    // Verify database state: row count must be either 0 or 1, never corrupted
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = 715415",
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();

    assert!(
        count.0 == 0 || count.0 == 1,
        "Row count must be 0 or 1, got {}",
        count.0
    );
}

/// Scenario 1b: Rapid concurrent toggle requests when recipe is ALREADY favorited.
#[tokio::test]
async fn test_adversarial_rapid_concurrent_toggles_when_initially_favorited() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "race_user_fav", "race_fav@bepviet.vn").await;

    // Initially add to favorites
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    let app = Arc::new(app);
    let token = Arc::new(token);

    let concurrent_requests = 16;
    let mut join_set = JoinSet::new();

    for _ in 0..concurrent_requests {
        let app_clone = Arc::clone(&app);
        let token_clone = Arc::clone(&token);
        join_set.spawn(async move {
            send_request(
                &app_clone,
                "POST",
                "/api/Recipes/715415/favorite",
                Some(&token_clone),
                None,
            )
            .await
        });
    }

    let mut results = Vec::new();
    while let Some(res) = join_set.join_next().await {
        results.push(res.unwrap());
    }

    let server_errors: Vec<_> = results
        .iter()
        .filter(|(s, _)| *s == StatusCode::INTERNAL_SERVER_ERROR)
        .collect();

    assert!(
        server_errors.is_empty(),
        "Concurrent toggles when initially favorited should not 500! Errors: {:?}",
        server_errors
    );

    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = 715415",
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();

    assert!(count.0 == 0 || count.0 == 1);
}


/// Scenario 2: Double-toggle in rapid sequential succession (state inversion parity).
#[tokio::test]
async fn test_adversarial_rapid_sequential_toggle_parity() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "seq_user", "seq@bepviet.vn").await;

    // Toggle 30 times sequentially
    for i in 1..=30 {
        let (status, body) = send_request(
            &app,
            "POST",
            "/api/Recipes/715415/favorite",
            Some(&token),
            None,
        )
        .await;

        assert_eq!(status, StatusCode::OK);
        let expected_favorited = (i % 2) == 1;
        assert_eq!(
            body["isFavorited"], expected_favorited,
            "Iteration {} expected isFavorited={}",
            i, expected_favorited
        );

        let count: (i64,) = sqlx::query_as(
            "SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = 715415",
        )
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();

        let expected_count = if expected_favorited { 1 } else { 0 };
        assert_eq!(count.0, expected_count);
    }
}

/// Scenario 3: Multi-user high-contention favorites on shared recipes.
#[tokio::test]
async fn test_adversarial_multi_user_concurrent_toggle_isolation() {
    let (app, pool) = setup_test_app().await;
    let app = Arc::new(app);

    // Create 5 users
    let mut users = Vec::new();
    for i in 0..5 {
        let (uid, tok) = create_test_user(&pool, &format!("m_user_{}", i), &format!("m{}@bepviet.vn", i)).await;
        users.push((uid, tok));
    }

    let mut join_set = JoinSet::new();
    for (_uid, tok) in &users {
        let app_clone = Arc::clone(&app);
        let token_clone = tok.clone();
        join_set.spawn(async move {
            send_request(
                &app_clone,
                "POST",
                "/api/Recipes/715415/favorite",
                Some(&token_clone),
                None,
            )
            .await
        });
    }

    while let Some(res) = join_set.join_next().await {
        let (status, body) = res.unwrap();
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["isFavorited"], true);
    }

    // Verify all 5 users have their own favorite record for 715415
    for (uid, tok) in &users {
        let (status, body) = send_request(&app, "GET", "/api/Recipes/favorites", Some(tok), None).await;
        assert_eq!(status, StatusCode::OK);
        let items = body.as_array().unwrap();
        assert_eq!(items.len(), 1, "User {} should have exactly 1 favorite", uid);
        assert_eq!(items[0]["id"], 715415);
    }

    let total_favs: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE recipe_id = 715415")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(total_favs.0, 5);
}

/// Scenario 4: Foreign Key and Cascade Deletion integrity when a Recipe is deleted.
#[tokio::test]
async fn test_adversarial_recipe_deletion_cascade_cleanup() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "fk_user_1", "fk1@bepviet.vn").await;

    // 1. Favorite recipe 715415
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    // Verify favorite exists in DB
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = 715415",
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(count.0, 1);

    // 2. Delete recipe 715415 directly from database
    sqlx::query("DELETE FROM recipes WHERE id = 715415")
        .execute(&pool)
        .await
        .unwrap();

    // 3. Verify SQLite ON DELETE CASCADE removed it from user_favorites
    let count_after: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM user_favorites WHERE recipe_id = 715415",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(count_after.0, 0, "user_favorites row should be cascaded when recipe is deleted");

    // 4. Query favorites via GET /api/Recipes/favorites -> returns 0 items without error
    let (status, body) = send_request(&app, "GET", "/api/Recipes/favorites", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body.as_array().unwrap().len(), 0);

    // 5. Attempting to toggle favorite on the now-deleted recipe returns 404 NOT_FOUND
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}

/// Scenario 5: Foreign Key and Cascade Deletion integrity when a User is deleted.
#[tokio::test]
async fn test_adversarial_user_deletion_cascade_cleanup() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "fk_user_2", "fk2@bepviet.vn").await;

    // 1. Favorite recipe 716406
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/716406/favorite",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    // 2. Delete user
    sqlx::query("DELETE FROM users WHERE id = ?")
        .bind(user_id)
        .execute(&pool)
        .await
        .unwrap();

    // 3. Verify user_favorites row is cascaded away
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM user_favorites WHERE user_id = ?",
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(count.0, 0, "user_favorites row should be cascaded when user is deleted");

    // 4. Token for deleted user should now be rejected with 401 Unauthorized
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/716406/favorite",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
}

/// Scenario 6: Batch sync with large payload (500 IDs with mixed valid and non-existent IDs).
#[tokio::test]
async fn test_adversarial_batch_sync_large_payload() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "sync_stress_user", "sync_stress@bepviet.vn").await;

    // Create 500 IDs: 3 valid ones, 497 non-existent ones
    let mut ids = vec![715415, 716406, 644387];
    for fake_id in 900000..900497 {
        ids.push(fake_id);
    }

    let payload = json!(ids);
    let (status, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(payload),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["syncedCount"], 3, "Only the 3 existing recipes should be synced");

    // Verify database count for user
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 3);
}

/// Scenario 7: Batch sync with negative and zero IDs (boundary values).
#[tokio::test]
async fn test_adversarial_batch_sync_negative_and_zero_ids() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "bound_user", "bound@bepviet.vn").await;

    // Payload with negative, zero, and valid IDs
    let payload = json!([-999, -1, 0, 715415, i64::MAX]);
    let (status, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(payload),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["syncedCount"], 1);
}

/// Scenario 8: Concurrent batch syncs by the same user (idempotency race).
#[tokio::test]
async fn test_adversarial_concurrent_batch_syncs() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "sync_race_user", "sync_race@bepviet.vn").await;
    let app = Arc::new(app);
    let token = Arc::new(token);

    let mut join_set = JoinSet::new();
    for _ in 0..10 {
        let app_clone = Arc::clone(&app);
        let token_clone = Arc::clone(&token);
        join_set.spawn(async move {
            let payload = json!([715415, 716406, 644387]);
            send_request(
                &app_clone,
                "POST",
                "/api/Recipes/sync-favorites",
                Some(&token_clone),
                Some(payload),
            )
            .await
        });
    }

    let mut total_synced_sum = 0;
    while let Some(res) = join_set.join_next().await {
        let (status, body) = res.unwrap();
        assert_eq!(status, StatusCode::OK);
        let synced = body["syncedCount"].as_u64().unwrap();
        total_synced_sum += synced;
    }

    // In an idempotent concurrent batch sync, exactly 3 rows total must be inserted
    assert_eq!(
        total_synced_sum, 3,
        "Sum of syncedCount across concurrent syncs must equal exactly the unique valid items"
    );

    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 3);
}

/// Scenario 9: Non-existent recipe ID boundary tests for toggle.
#[tokio::test]
async fn test_adversarial_toggle_nonexistent_and_extreme_ids() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "edge_user", "edge@bepviet.vn").await;

    let test_ids = [0, -1, -999999, 99999999, i64::MAX];
    for test_id in test_ids {
        let (status, body) = send_request(
            &app,
            "POST",
            &format!("/api/Recipes/{}/favorite", test_id),
            Some(&token),
            None,
        )
        .await;

        assert_eq!(
            status,
            StatusCode::NOT_FOUND,
            "ID {} should return 404 NOT FOUND, got {}: {:?}",
            test_id,
            status,
            body
        );
    }
}

/// Scenario 10: Concurrent batch sync and toggle interleaving on the same recipe.
#[tokio::test]
async fn test_adversarial_concurrent_sync_and_toggle_interleaving() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "interleave_user", "interleave@bepviet.vn").await;
    let app = Arc::new(app);
    let token = Arc::new(token);

    let mut join_set = JoinSet::new();

    // 5 sync requests and 5 toggle requests simultaneously
    for _ in 0..5 {
        let a = Arc::clone(&app);
        let t = Arc::clone(&token);
        join_set.spawn(async move {
            send_request(
                &a,
                "POST",
                "/api/Recipes/sync-favorites",
                Some(&t),
                Some(json!([715415])),
            )
            .await
        });

        let a2 = Arc::clone(&app);
        let t2 = Arc::clone(&token);
        join_set.spawn(async move {
            send_request(
                &a2,
                "POST",
                "/api/Recipes/715415/favorite",
                Some(&t2),
                None,
            )
            .await
        });
    }

    let mut results = Vec::new();
    while let Some(res) = join_set.join_next().await {
        results.push(res.unwrap());
    }

    let server_errors: Vec<_> = results
        .iter()
        .filter(|(s, _)| *s == StatusCode::INTERNAL_SERVER_ERROR)
        .collect();

    // Verify if sync or toggle produced 500 error
    assert!(
        server_errors.is_empty(),
        "Interleaved sync & toggle should not cause 500 Internal Server Error, got: {:?}",
        server_errors
    );

    // Database state must be valid (either 0 or 1 row)
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = 715415",
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert!(count.0 == 0 || count.0 == 1);
}

/// Scenario 11: Barrier-synchronized 64-task extreme concurrency hammer on a single recipe.
/// Uses a barrier so all 64 requests hit the endpoint at the exact same instant.
#[tokio::test]
async fn test_adversarial_barrier_64_task_concurrency_hammer() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "barrier_user", "barrier@bepviet.vn").await;
    let app = Arc::new(app);
    let token = Arc::new(token);

    let num_tasks = 64;
    let barrier = Arc::new(tokio::sync::Barrier::new(num_tasks));
    let mut join_set = JoinSet::new();

    for _ in 0..num_tasks {
        let app_clone = Arc::clone(&app);
        let token_clone = Arc::clone(&token);
        let b = Arc::clone(&barrier);
        join_set.spawn(async move {
            b.wait().await;
            send_request(
                &app_clone,
                "POST",
                "/api/Recipes/715415/favorite",
                Some(&token_clone),
                None,
            )
            .await
        });
    }

    let mut results = Vec::new();
    while let Some(res) = join_set.join_next().await {
        results.push(res.unwrap());
    }

    // Verify: Zero 500 errors, all 200 OK
    let server_errors: Vec<_> = results
        .iter()
        .filter(|(s, _)| *s != StatusCode::OK)
        .collect();

    assert!(
        server_errors.is_empty(),
        "All 64 concurrent requests must return 200 OK, got failures: {:?}",
        server_errors
    );

    // Verify row count is strictly 0 or 1
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = 715415",
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();

    assert!(
        count.0 == 0 || count.0 == 1,
        "Database integrity broken: row count is {}",
        count.0
    );
}

/// Scenario 12: High-contention mixed workload with Barrier (20 Readers + 20 Toggles + 20 Syncers).
#[tokio::test]
async fn test_adversarial_mixed_readers_writers_syncers_hammer() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "mixed_user", "mixed@bepviet.vn").await;
    let app = Arc::new(app);
    let token = Arc::new(token);

    let total_tasks = 60;
    let barrier = Arc::new(tokio::sync::Barrier::new(total_tasks));
    let mut join_set = JoinSet::new();

    // 20 Toggles
    for _ in 0..20 {
        let a = Arc::clone(&app);
        let t = Arc::clone(&token);
        let b = Arc::clone(&barrier);
        join_set.spawn(async move {
            b.wait().await;
            send_request(
                &a,
                "POST",
                "/api/Recipes/715415/favorite",
                Some(&t),
                None,
            )
            .await
        });
    }

    // 20 Readers
    for _ in 0..20 {
        let a = Arc::clone(&app);
        let t = Arc::clone(&token);
        let b = Arc::clone(&barrier);
        join_set.spawn(async move {
            b.wait().await;
            send_request(
                &a,
                "GET",
                "/api/Recipes/favorites",
                Some(&t),
                None,
            )
            .await
        });
    }

    // 20 Batch Syncers
    for _ in 0..20 {
        let a = Arc::clone(&app);
        let t = Arc::clone(&token);
        let b = Arc::clone(&barrier);
        join_set.spawn(async move {
            b.wait().await;
            send_request(
                &a,
                "POST",
                "/api/Recipes/sync-favorites",
                Some(&t),
                Some(json!([715415, 716406])),
            )
            .await
        });
    }

    let mut all_ok = true;
    let mut errors = Vec::new();
    while let Some(res) = join_set.join_next().await {
        let (status, body) = res.unwrap();
        if status != StatusCode::OK {
            all_ok = false;
            errors.push((status, body));
        }
    }

    assert!(
        all_ok,
        "All 60 mixed operations must return 200 OK without lock contention errors: {:?}",
        errors
    );

    // Verify DB integrity
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = 715415",
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();

    assert!(count.0 == 0 || count.0 == 1);
}

/// Scenario 13: Multi-round flip-flop stress (5 sequential rounds of 20 concurrent toggles).
#[tokio::test]
async fn test_adversarial_multiround_rapid_flipflop() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "flipflop_user", "flip@bepviet.vn").await;
    let app = Arc::new(app);
    let token = Arc::new(token);

    for round in 1..=5 {
        let mut join_set = JoinSet::new();
        for _ in 0..20 {
            let a = Arc::clone(&app);
            let t = Arc::clone(&token);
            join_set.spawn(async move {
                send_request(
                    &a,
                    "POST",
                    "/api/Recipes/715415/favorite",
                    Some(&t),
                    None,
                )
                .await
            });
        }

        while let Some(res) = join_set.join_next().await {
            let (status, _) = res.unwrap();
            assert_eq!(
                status,
                StatusCode::OK,
                "Round {} encountered non-200 status",
                round
            );
        }

        let count: (i64,) = sqlx::query_as(
            "SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = 715415",
        )
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();

        assert!(
            count.0 == 0 || count.0 == 1,
            "Round {}: row count must be 0 or 1, got {}",
            round,
            count.0
        );
    }
}

