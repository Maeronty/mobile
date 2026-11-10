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

fn encode_uri(uri: &str) -> String {
    let mut encoded = String::with_capacity(uri.len() * 2);
    for b in uri.bytes() {
        match b {
            b' ' => encoded.push_str("%20"),
            0..=31 | 127..=255 => {
                encoded.push_str(&format!("%{:02X}", b));
            }
            _ => encoded.push(b as char),
        }
    }
    encoded
}

async fn send_request(
    app: &Router,
    method: &str,
    uri: &str,
    token: Option<&str>,
    body: Option<Value>,
) -> (StatusCode, Value) {
    let safe_uri = encode_uri(uri);
    let mut builder = Request::builder()
        .method(method)
        .uri(&safe_uri)
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

// ============================================================================
// TEST 1: HIGH-CONCURRENCY IDENTICAL INGREDIENT ADDITIONS (50 tasks)
// Spawn 50 concurrent tasks attempting to add the same ingredient ("thịt bò")
// for the same user simultaneously. Verify amounts accumulate correctly,
// no duplicate records are created, and no database lock timeouts or panics occur.
// ============================================================================
#[tokio::test]
async fn test_01_high_concurrency_simultaneous_identical_additions() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "concurr_user_1", "concurr1@bepviet.vn").await;

    let app = Arc::new(app);
    let token = Arc::new(token);
    let num_tasks = 50;
    let mut join_set = JoinSet::new();

    let variations = [
        "thịt bò",
        "Thịt Bò",
        "THỊT BÒ",
        "  thịt bò  ",
        "thịt bò ",
    ];

    for i in 0..num_tasks {
        let app_clone = Arc::clone(&app);
        let token_clone = Arc::clone(&token);
        let name_var = variations[i % variations.len()].to_string();

        join_set.spawn(async move {
            let payload = json!({
                "name": name_var,
                "amount": 10.0,
                "unit": "g",
                "notes": "Ngăn mát"
            });
            send_request(&app_clone, "POST", "/api/pantry", Some(&token_clone), Some(payload)).await
        });
    }

    let mut success_count = 0;
    let mut status_codes = Vec::new();

    while let Some(res) = join_set.join_next().await {
        let (status, body) = res.expect("Task panicked");
        status_codes.push(status);
        if status == StatusCode::CREATED {
            success_count += 1;
        } else {
            eprintln!("Unexpected status: {} body: {:?}", status, body);
        }
    }

    assert_eq!(
        success_count, num_tasks,
        "All {} concurrent requests should return 201 Created. Received: {:?}",
        num_tasks, status_codes
    );

    // Direct database validation: exactly 1 row should exist for user_id
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(
        count.0, 1,
        "Expected exactly 1 pantry record for 'thịt bò', but found {}",
        count.0
    );

    // Amount accumulated validation: 50 * 10.0 = 500.0
    let item_row: (String, f64, String) = sqlx::query_as(
        "SELECT name, amount, unit FROM pantry_items WHERE user_id = ?"
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();

    assert_eq!(item_row.0, "thịt bò");
    let expected_amount = num_tasks as f64 * 10.0;
    assert!(
        (item_row.1 - expected_amount).abs() < 1e-4,
        "Expected accumulated amount {}, got {}",
        expected_amount,
        item_row.1
    );

    // API GET validation
    let (get_status, get_body) = send_request(&app, "GET", "/api/pantry", Some(&token), None).await;
    assert_eq!(get_status, StatusCode::OK);
    let items = get_body["items"].as_array().expect("items should be an array");
    assert_eq!(items.len(), 1);
    let ingredient_names = get_body["ingredientNames"].as_array().expect("ingredientNames should be an array");
    assert_eq!(ingredient_names.len(), 1);
    assert_eq!(ingredient_names[0].as_str().unwrap(), "thịt bò");
}

// ============================================================================
// TEST 2: CONCURRENT DISTINCT ADDITIONS (20 tasks)
// 20 concurrent tasks adding different ingredients for the same user.
// Verify all items exist and ingredientNames contains all of them.
// ============================================================================
#[tokio::test]
async fn test_02_concurrent_distinct_additions() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "distinct_user_2", "distinct2@bepviet.vn").await;

    let ingredients = [
        "thịt bò", "thịt heo", "thịt gà", "cá hồi", "tôm sú",
        "hành lá", "hành tây", "tỏi", "ớt hiểm", "gừng tươi",
        "sả cây", "tiêu đen", "nước mắm", "đường cát", "muối tinh",
        "dầu ăn", "cà rốt", "khoai tây", "cà chua", "trứng gà",
    ];

    let app = Arc::new(app);
    let token = Arc::new(token);
    let mut join_set = JoinSet::new();

    for ing in ingredients.iter() {
        let app_clone = Arc::clone(&app);
        let token_clone = Arc::clone(&token);
        let name = ing.to_string();

        join_set.spawn(async move {
            let payload = json!({
                "name": name,
                "amount": 100.0,
                "unit": "g"
            });
            send_request(&app_clone, "POST", "/api/pantry", Some(&token_clone), Some(payload)).await
        });
    }

    let mut success_count = 0;
    while let Some(res) = join_set.join_next().await {
        let (status, _) = res.expect("Task panicked");
        if status == StatusCode::CREATED {
            success_count += 1;
        }
    }

    assert_eq!(success_count, 20, "All 20 distinct additions should succeed with 201 Created");

    // Verify DB count
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 20, "Database should contain exactly 20 distinct records");

    // Verify API GET response
    let (status, body) = send_request(&app, "GET", "/api/pantry", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);

    let items = body["items"].as_array().expect("items must be array");
    assert_eq!(items.len(), 20);

    let ingredient_names = body["ingredientNames"].as_array().expect("ingredientNames must be array");
    assert_eq!(ingredient_names.len(), 20);

    let returned_names: Vec<String> = ingredient_names
        .iter()
        .map(|v| v.as_str().unwrap().to_lowercase())
        .collect();

    for expected in ingredients.iter() {
        assert!(
            returned_names.contains(&expected.to_lowercase()),
            "Missing ingredient in ingredientNames: {}",
            expected
        );
    }
}

// ============================================================================
// TEST 3: CROSS-TENANT CONCURRENCY ISOLATION
// User A and User B concurrently adding, updating, and clearing their pantries.
// Verify that User A's clear does NOT delete User B's items, User B cannot
// read User A's items, and total counts for both users remain strictly isolated.
// ============================================================================
#[tokio::test]
async fn test_03_cross_tenant_concurrency_isolation() {
    let (app, pool) = setup_test_app().await;
    let (user_a, token_a) = create_test_user(&pool, "tenant_a", "tenant_a@bepviet.vn").await;
    let (user_b, token_b) = create_test_user(&pool, "tenant_b", "tenant_b@bepviet.vn").await;

    let app = Arc::new(app);
    let token_a = Arc::new(token_a);
    let token_b = Arc::new(token_b);

    // Phase 1: Concurrently populate 15 items for User A and 15 items for User B
    let mut populate_set = JoinSet::new();

    for i in 0..15 {
        let app_clone = Arc::clone(&app);
        let tok_a = Arc::clone(&token_a);
        populate_set.spawn(async move {
            let payload = json!({
                "name": format!("a_ingredient_{}", i),
                "amount": (i + 1) as f64 * 10.0,
                "unit": "g"
            });
            send_request(&app_clone, "POST", "/api/pantry", Some(&tok_a), Some(payload)).await
        });

        let app_clone = Arc::clone(&app);
        let tok_b = Arc::clone(&token_b);
        populate_set.spawn(async move {
            let payload = json!({
                "name": format!("b_ingredient_{}", i),
                "amount": (i + 1) as f64 * 20.0,
                "unit": "ml"
            });
            send_request(&app_clone, "POST", "/api/pantry", Some(&tok_b), Some(payload)).await
        });
    }

    while let Some(res) = populate_set.join_next().await {
        let (status, _) = res.expect("Task panicked");
        assert_eq!(status, StatusCode::CREATED);
    }

    // Verify initial counts: 15 for A, 15 for B
    let count_a: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_a)
        .fetch_one(&pool)
        .await
        .unwrap();
    let count_b: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_b)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count_a.0, 15);
    assert_eq!(count_b.0, 15);

    // Phase 2: Simultaneous conflict - User A triggers clear_pantry (`DELETE /api/pantry`)
    // while User B concurrently adds 5 more items and updates an existing item.
    let mut cross_action_set = JoinSet::new();

    // User A clears pantry
    let app_clone = Arc::clone(&app);
    let tok_a = Arc::clone(&token_a);
    cross_action_set.spawn(async move {
        send_request(&app_clone, "DELETE", "/api/pantry", Some(&tok_a), None).await
    });

    // User B adds 5 items concurrently
    for i in 15..20 {
        let app_clone = Arc::clone(&app);
        let tok_b = Arc::clone(&token_b);
        cross_action_set.spawn(async move {
            let payload = json!({
                "name": format!("b_ingredient_{}", i),
                "amount": 50.0,
                "unit": "g"
            });
            send_request(&app_clone, "POST", "/api/pantry", Some(&tok_b), Some(payload)).await
        });
    }

    while let Some(res) = cross_action_set.join_next().await {
        let (status, _) = res.expect("Cross action panicked");
        assert!(
            status == StatusCode::OK || status == StatusCode::CREATED,
            "Cross actions must return 200 or 201, got {}",
            status
        );
    }

    // Phase 3: Assert cross-tenant isolation
    // User A must have 0 items
    let final_count_a: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_a)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(final_count_a.0, 0, "User A pantry must be completely empty after clear");

    // User B must have exactly 20 items (15 initial + 5 added), entirely unharmed by User A's clear
    let final_count_b: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_b)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(
        final_count_b.0, 20,
        "User B pantry must retain exactly 20 items. User A's clear must not leak into User B's domain!"
    );

    // Verify User A GET returns empty
    let (status_a, body_a) = send_request(&app, "GET", "/api/pantry", Some(&token_a), None).await;
    assert_eq!(status_a, StatusCode::OK);
    assert_eq!(body_a["items"].as_array().unwrap().len(), 0);
    assert_eq!(body_a["ingredientNames"].as_array().unwrap().len(), 0);

    // Verify User B GET returns 20 items, none of which belong to User A
    let (status_b, body_b) = send_request(&app, "GET", "/api/pantry", Some(&token_b), None).await;
    assert_eq!(status_b, StatusCode::OK);
    let items_b = body_b["items"].as_array().unwrap();
    assert_eq!(items_b.len(), 20);

    for it in items_b {
        let name = it["name"].as_str().unwrap();
        assert!(
            name.starts_with("b_ingredient_"),
            "Tenant B leaked item from Tenant A: {}",
            name
        );
    }
}

// ============================================================================
// TEST 4: RACE CONDITION ON UPDATE / DELETE ON SAME ITEM ID
// Concurrent requests updating and deleting the same item ID to ensure no database
// deadlock and deterministic response (either 200 or 404).
// ============================================================================
#[tokio::test]
async fn test_04_race_condition_update_and_delete_same_item() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "race_target_user", "race_target@bepviet.vn").await;

    // Create an initial target item
    let payload = json!({
        "name": "thịt gà ta",
        "amount": 500.0,
        "unit": "g"
    });
    let (status, create_body) = send_request(&app, "POST", "/api/pantry", Some(&token), Some(payload)).await;
    assert_eq!(status, StatusCode::CREATED);
    let item_id = create_body["item"]["id"].as_i64().expect("item id must exist");

    let app = Arc::new(app);
    let token = Arc::new(token);
    let mut join_set = JoinSet::new();

    // Spawn 15 concurrent PUT updates and 15 concurrent DELETE requests
    for i in 0..15 {
        let app_clone = Arc::clone(&app);
        let tok_clone = Arc::clone(&token);
        let update_url = format!("/api/pantry/{}", item_id);
        join_set.spawn(async move {
            let update_body = json!({
                "amount": 600.0 + (i as f64 * 10.0),
                "notes": format!("Update attempt {}", i)
            });
            ("UPDATE", send_request(&app_clone, "PUT", &update_url, Some(&tok_clone), Some(update_body)).await)
        });

        let app_clone = Arc::clone(&app);
        let tok_clone = Arc::clone(&token);
        let del_url = format!("/api/pantry/{}", item_id);
        join_set.spawn(async move {
            ("DELETE", send_request(&app_clone, "DELETE", &del_url, Some(&tok_clone), None).await)
        });
    }

    let mut update_200 = 0;
    let mut update_404 = 0;
    let mut delete_200 = 0;
    let mut delete_404 = 0;
    let mut unexpected_statuses = Vec::new();

    while let Some(res) = join_set.join_next().await {
        let (op_type, (status, body)) = res.expect("Task panicked");
        match (op_type, status) {
            ("UPDATE", StatusCode::OK) => update_200 += 1,
            ("UPDATE", StatusCode::NOT_FOUND) => update_404 += 1,
            ("DELETE", StatusCode::OK) => delete_200 += 1,
            ("DELETE", StatusCode::NOT_FOUND) => delete_404 += 1,
            _ => unexpected_statuses.push((op_type, status, body)),
        }
    }

    assert!(
        unexpected_statuses.is_empty(),
        "All concurrent operations must return 200 or 404, but encountered unexpected: {:?}",
        unexpected_statuses
    );

    // At least one delete returned 200 OK (the deletion succeeded)
    assert!(
        delete_200 >= 1,
        "At least one DELETE must succeed with 200 OK"
    );

    // Total operations count = 30
    assert_eq!(update_200 + update_404, 15);
    assert_eq!(delete_200 + delete_404, 15);

    // Final state verification: item must be deleted from pantry
    let (final_status, final_body) = send_request(&app, "GET", "/api/pantry", Some(&token), None).await;
    assert_eq!(final_status, StatusCode::OK);
    let items = final_body["items"].as_array().unwrap();
    assert!(
        items.iter().all(|it| it["id"].as_i64().unwrap() != item_id),
        "Item {} should no longer exist in pantry",
        item_id
    );

    // Post-concurrency verification: Any subsequent update or delete on the deleted item ID
    // MUST now deterministically return 404 Not Found.
    let (post_update_status, _) = send_request(
        &app,
        "PUT",
        &format!("/api/pantry/{}", item_id),
        Some(&token),
        Some(json!({"amount": 10.0})),
    )
    .await;
    assert_eq!(
        post_update_status,
        StatusCode::NOT_FOUND,
        "Subsequent update on deleted item must return 404"
    );

    let (post_delete_status, _) = send_request(
        &app,
        "DELETE",
        &format!("/api/pantry/{}", item_id),
        Some(&token),
        None,
    )
    .await;
    assert_eq!(
        post_delete_status,
        StatusCode::NOT_FOUND,
        "Subsequent delete on deleted item must return 404"
    );
}

// ============================================================================
// TEST 5: CROSS-TENANT ADVERSARIAL MUTATION FLOOD
// User B attempts to concurrently modify and delete User A's items (30 tasks).
// Verify User B receives 100% 404 Not Found, no data leakage, and User A's items
// remain 100% intact.
// ============================================================================
#[tokio::test]
async fn test_05_cross_tenant_adversarial_mutation_flood() {
    let (app, pool) = setup_test_app().await;
    let (user_a, token_a) = create_test_user(&pool, "victim_a", "victim_a@bepviet.vn").await;
    let (_user_b, token_b) = create_test_user(&pool, "attacker_b", "attacker_b@bepviet.vn").await;

    // User A creates 5 items
    let mut a_item_ids = Vec::new();
    for i in 0..5 {
        let payload = json!({
            "name": format!("secret_recipe_spice_{}", i),
            "amount": 100.0,
            "unit": "g"
        });
        let (status, body) = send_request(&app, "POST", "/api/pantry", Some(&token_a), Some(payload)).await;
        assert_eq!(status, StatusCode::CREATED);
        a_item_ids.push(body["item"]["id"].as_i64().unwrap());
    }

    let app = Arc::new(app);
    let token_b = Arc::new(token_b);
    let mut flood_set = JoinSet::new();

    // Attacker B launches 30 concurrent PUT and DELETE attacks against User A's items
    for i in 0..30 {
        let app_clone = Arc::clone(&app);
        let tok_b = Arc::clone(&token_b);
        let target_id = a_item_ids[i % a_item_ids.len()];

        if i % 2 == 0 {
            // Malicious PUT
            flood_set.spawn(async move {
                let payload = json!({
                    "name": "hacked_name",
                    "amount": 99999.0
                });
                send_request(&app_clone, "PUT", &format!("/api/pantry/{}", target_id), Some(&tok_b), Some(payload)).await
            });
        } else {
            // Malicious DELETE
            flood_set.spawn(async move {
                send_request(&app_clone, "DELETE", &format!("/api/pantry/{}", target_id), Some(&tok_b), None).await
            });
        }
    }

    let mut attack_404_count = 0;
    while let Some(res) = flood_set.join_next().await {
        let (status, _) = res.expect("Attack task panicked");
        if status == StatusCode::NOT_FOUND {
            attack_404_count += 1;
        }
    }

    assert_eq!(
        attack_404_count, 30,
        "Every cross-tenant mutation/deletion attempt must return 404 Not Found"
    );

    // Verify User A's items are completely unchanged
    let (status_a, body_a) = send_request(&app, "GET", "/api/pantry", Some(&token_a), None).await;
    assert_eq!(status_a, StatusCode::OK);
    let items_a = body_a["items"].as_array().unwrap();
    assert_eq!(items_a.len(), 5);

    for it in items_a {
        let name = it["name"].as_str().unwrap();
        assert!(
            name.starts_with("secret_recipe_spice_"),
            "Item name was corrupted: {}",
            name
        );
        let amt = it["amount"].as_f64().unwrap();
        assert_eq!(amt, 100.0, "Item amount was altered: {}", amt);
    }

    // Direct database validation
    let db_items_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_a)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(db_items_count.0, 5);
}

// ============================================================================
// TEST 6: HIGH-CONCURRENCY BATCH AND SINGLE INTERLEAVING HAMMER
// Interleave batch array, batch object, and single additions concurrently.
// Verify atomic deduplication, amount accumulation, and zero database locks.
// ============================================================================
#[tokio::test]
async fn test_06_concurrent_batch_and_single_interleaving_hammer() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "hammer_user", "hammer@bepviet.vn").await;

    let app = Arc::new(app);
    let token = Arc::new(token);
    let mut join_set = JoinSet::new();

    // 10 tasks: batch string array ["hành lá", "ngò rí", "tiêu đen"]
    for _ in 0..10 {
        let app_clone = Arc::clone(&app);
        let tok = Arc::clone(&token);
        join_set.spawn(async move {
            let payload = json!(["hành lá", "ngò rí", "tiêu đen"]);
            send_request(&app_clone, "POST", "/api/pantry", Some(&tok), Some(payload)).await
        });
    }

    // 10 tasks: single item {"name": "hành lá", "amount": 5.0}
    for _ in 0..10 {
        let app_clone = Arc::clone(&app);
        let tok = Arc::clone(&token);
        join_set.spawn(async move {
            let payload = json!({
                "name": "hành lá",
                "amount": 5.0,
                "unit": "cây"
            });
            send_request(&app_clone, "POST", "/api/pantry", Some(&tok), Some(payload)).await
        });
    }

    // 10 tasks: batch objects [{"name": "ngò rí", "amount": 2.0}, {"name": "ớt cay", "amount": 3.0}]
    for _ in 0..10 {
        let app_clone = Arc::clone(&app);
        let tok = Arc::clone(&token);
        join_set.spawn(async move {
            let payload = json!([
                {"name": "ngò rí", "amount": 2.0, "unit": "g"},
                {"name": "ớt cay", "amount": 3.0, "unit": "trái"}
            ]);
            send_request(&app_clone, "POST", "/api/pantry", Some(&tok), Some(payload)).await
        });
    }

    let mut success_count = 0;
    while let Some(res) = join_set.join_next().await {
        let (status, _) = res.expect("Hammer task panicked");
        if status == StatusCode::CREATED {
            success_count += 1;
        }
    }

    assert_eq!(success_count, 30, "All 30 concurrent hammer operations must return 201 Created");

    // Total distinct ingredients should be exactly 4:
    // "hành lá", "ngò rí", "tiêu đen", "ớt cay"
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(
        count.0, 4,
        "Expected exactly 4 distinct pantry records, but found {}",
        count.0
    );

    // Verify amounts:
    // "hành lá": 10 tasks of batch (1.0 each) + 10 tasks of single (5.0 each) = 10*1.0 + 10*5.0 = 60.0
    let hanh_la_amt: (f64,) = sqlx::query_as(
        "SELECT amount FROM pantry_items WHERE user_id = ? AND LOWER(TRIM(name)) = 'hành lá'"
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert!(
        (hanh_la_amt.0 - 60.0).abs() < 1e-4,
        "Expected 60.0 for hành lá, got {}",
        hanh_la_amt.0
    );

    // "ngò rí": 10 tasks of batch (1.0 each) + 10 tasks of object (2.0 each) = 10*1.0 + 10*2.0 = 30.0
    let ngo_ri_amt: (f64,) = sqlx::query_as(
        "SELECT amount FROM pantry_items WHERE user_id = ? AND LOWER(TRIM(name)) = 'ngò rí'"
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert!(
        (ngo_ri_amt.0 - 30.0).abs() < 1e-4,
        "Expected 30.0 for ngò rí, got {}",
        ngo_ri_amt.0
    );

    // "tiêu đen": 10 tasks of batch (1.0 each) = 10.0
    let tieu_den_amt: (f64,) = sqlx::query_as(
        "SELECT amount FROM pantry_items WHERE user_id = ? AND LOWER(TRIM(name)) = 'tiêu đen'"
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert!(
        (tieu_den_amt.0 - 10.0).abs() < 1e-4,
        "Expected 10.0 for tiêu đen, got {}",
        tieu_den_amt.0
    );

    // "ớt cay": 10 tasks of object (3.0 each) = 30.0
    let ot_cay_amt: (f64,) = sqlx::query_as(
        "SELECT amount FROM pantry_items WHERE user_id = ? AND LOWER(TRIM(name)) = 'ớt cay'"
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert!(
        (ot_cay_amt.0 - 30.0).abs() < 1e-4,
        "Expected 30.0 for ớt cay, got {}",
        ot_cay_amt.0
    );
}

// ============================================================================
// TEST 7: DUAL ROUTE CONCURRENT ACCESS PARITY (/api/pantry vs /api/kitchen-bag)
// Half of concurrent tasks target /api/pantry, half target /api/kitchen-bag.
// Verify perfect datastore convergence and zero race conflicts between alias routes.
// ============================================================================
#[tokio::test]
async fn test_07_concurrent_dual_route_pantry_and_kitchen_bag_parity() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "dual_route_user", "dual@bepviet.vn").await;

    let app = Arc::new(app);
    let token = Arc::new(token);
    let mut join_set = JoinSet::new();

    // 15 tasks sending to /api/pantry
    for i in 0..15 {
        let app_clone = Arc::clone(&app);
        let tok = Arc::clone(&token);
        join_set.spawn(async move {
            let payload = json!({
                "name": format!("pantry_alias_item_{}", i),
                "amount": 10.0
            });
            send_request(&app_clone, "POST", "/api/pantry", Some(&tok), Some(payload)).await
        });
    }

    // 15 tasks sending to /api/kitchen-bag
    for i in 0..15 {
        let app_clone = Arc::clone(&app);
        let tok = Arc::clone(&token);
        join_set.spawn(async move {
            let payload = json!({
                "name": format!("kitchenbag_alias_item_{}", i),
                "amount": 20.0
            });
            send_request(&app_clone, "POST", "/api/kitchen-bag", Some(&tok), Some(payload)).await
        });
    }

    while let Some(res) = join_set.join_next().await {
        let (status, _) = res.expect("Dual route task panicked");
        assert_eq!(status, StatusCode::CREATED);
    }

    // Verify DB count = 30
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 30);

    // Verify GET /api/pantry returns all 30
    let (status_pantry, body_pantry) = send_request(&app, "GET", "/api/pantry", Some(&token), None).await;
    assert_eq!(status_pantry, StatusCode::OK);
    assert_eq!(body_pantry["items"].as_array().unwrap().len(), 30);

    // Verify GET /api/kitchen-bag returns identical 30 items
    let (status_kb, body_kb) = send_request(&app, "GET", "/api/kitchen-bag", Some(&token), None).await;
    assert_eq!(status_kb, StatusCode::OK);
    assert_eq!(body_kb["items"].as_array().unwrap().len(), 30);
    assert_eq!(body_pantry["ingredientNames"], body_kb["ingredientNames"]);
}

// ============================================================================
// TEST 8: CONCURRENT READ AND CLEAR INTEGRITY
// Concurrently fire 20 GET requests while a DELETE /api/pantry (clear) is executing.
// Verify no SQLite database lock error (500) and that every response is valid JSON.
// ============================================================================
#[tokio::test]
async fn test_08_concurrent_read_and_clear_integrity() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "read_clear_user", "read_clear@bepviet.vn").await;

    // Seed 20 items first
    for i in 0..20 {
        let payload = json!({
            "name": format!("item_to_read_{}", i),
            "amount": 1.0
        });
        let (status, _) = send_request(&app, "POST", "/api/pantry", Some(&token), Some(payload)).await;
        assert_eq!(status, StatusCode::CREATED);
    }

    let app = Arc::new(app);
    let token = Arc::new(token);
    let mut join_set = JoinSet::new();

    // Spawn 20 concurrent readers
    for _ in 0..20 {
        let app_clone = Arc::clone(&app);
        let tok = Arc::clone(&token);
        join_set.spawn(async move {
            send_request(&app_clone, "GET", "/api/pantry", Some(&tok), None).await
        });
    }

    // Spawn 1 clear request
    let app_clone = Arc::clone(&app);
    let tok = Arc::clone(&token);
    join_set.spawn(async move {
        send_request(&app_clone, "DELETE", "/api/pantry", Some(&tok), None).await
    });

    while let Some(res) = join_set.join_next().await {
        let (status, body) = res.expect("Task panicked");
        assert_eq!(
            status,
            StatusCode::OK,
            "Every read or clear response must be 200 OK. Received: {} with body {:?}",
            status,
            body
        );
        // Either body is list response with items or clear response with message
        assert!(body.is_object(), "Response must be valid JSON object");
    }

    // Final verification: pantry is now cleared
    let (final_status, final_body) = send_request(&app, "GET", "/api/pantry", Some(&token), None).await;
    assert_eq!(final_status, StatusCode::OK);
    assert_eq!(final_body["items"].as_array().unwrap().len(), 0);
}
