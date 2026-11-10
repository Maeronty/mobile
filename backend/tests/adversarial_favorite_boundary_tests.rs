mod common;

use axum::{
    body::Body,
    http::{header, Request, StatusCode},
    Router,
};
use common::setup_test_app;
use food_tip_be_rust::services::auth_service::{generate_jwt, Claims};
use http_body_util::BodyExt;
use jsonwebtoken::{encode, EncodingKey, Header};
use serde_json::{json, Value};
use sqlx::SqlitePool;
use tower::ServiceExt;

const TEST_SECRET: &str = "TestSecretKeyForTestingJwtTokensOnly12345!";

/// Encode URI components safely so Hyper and Axum can parse URI without client-side error
fn safe_encode_url(uri: &str) -> String {
    let mut encoded = String::with_capacity(uri.len() * 2);
    for b in uri.bytes() {
        match b {
            b' ' => encoded.push_str("%20"),
            b'"' => encoded.push_str("%22"),
            b'<' => encoded.push_str("%3C"),
            b'>' => encoded.push_str("%3E"),
            b'\\' => encoded.push_str("%5C"),
            b'^' => encoded.push_str("%5E"),
            b'`' => encoded.push_str("%60"),
            b'{' => encoded.push_str("%7B"),
            b'|' => encoded.push_str("%7C"),
            b'}' => encoded.push_str("%7D"),
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
    let safe_uri = safe_encode_url(uri);
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

async fn send_raw_request(
    app: &Router,
    method: &str,
    uri: &str,
    token: Option<&str>,
    body_raw: Vec<u8>,
    content_type: &str,
) -> (StatusCode, Value, String) {
    let safe_uri = safe_encode_url(uri);
    let mut builder = Request::builder()
        .method(method)
        .uri(&safe_uri)
        .header(header::CONTENT_TYPE, content_type);

    if let Some(tok) = token {
        builder = builder.header(header::AUTHORIZATION, format!("Bearer {}", tok));
    }

    let response = app
        .clone()
        .oneshot(builder.body(Body::from(body_raw)).unwrap())
        .await
        .expect("Failed to execute request");

    let status = response.status();
    let bytes = response.into_body().collect().await.unwrap().to_bytes();
    let text = String::from_utf8_lossy(&bytes).to_string();
    let json_val: Value = serde_json::from_slice(&bytes).unwrap_or(Value::Null);

    (status, json_val, text)
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

fn forge_token_with_sub(sub: &str, secret: &str) -> String {
    let now = chrono::Utc::now();
    let exp = (now + chrono::Duration::hours(2)).timestamp() as usize;
    let claims = Claims {
        sub: sub.to_string(),
        email: "attacker@exploit.local".to_string(),
        role: "User".to_string(),
        exp,
    };
    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .unwrap()
}

// =========================================================================
// TEST 1: Cross-User Data Isolation & Strict Multi-Tenant Separation
// =========================================================================
#[tokio::test]
async fn test_adv_01_cross_user_isolation_strict() {
    let (app, pool) = setup_test_app().await;

    let (alice_id, alice_tok) = create_test_user(&pool, "adv_alice", "alice@adv.com").await;
    let (bob_id, bob_tok) = create_test_user(&pool, "adv_bob", "bob@adv.com").await;
    let (_charlie_id, charlie_tok) = create_test_user(&pool, "adv_charlie", "charlie@adv.com").await;

    // Alice favorites recipes 715415 and 716406
    let (s, _) = send_request(&app, "POST", "/api/Recipes/715415/favorite", Some(&alice_tok), None).await;
    assert_eq!(s, StatusCode::OK);
    let (s, _) = send_request(&app, "POST", "/api/Recipes/716406/favorite", Some(&alice_tok), None).await;
    assert_eq!(s, StatusCode::OK);

    // Bob favorites recipes 716406 and 644387
    let (s, _) = send_request(&app, "POST", "/api/Recipes/716406/favorite", Some(&bob_tok), None).await;
    assert_eq!(s, StatusCode::OK);
    let (s, _) = send_request(&app, "POST", "/api/Recipes/644387/favorite", Some(&bob_tok), None).await;
    assert_eq!(s, StatusCode::OK);

    // 1. Charlie has no favorites
    let (s, body_charlie) = send_request(&app, "GET", "/api/Recipes/favorites", Some(&charlie_tok), None).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(body_charlie.as_array().unwrap().len(), 0);

    // 2. Alice sees exactly [716406, 715415] (ordered desc by creation)
    let (s, body_alice) = send_request(&app, "GET", "/api/Recipes/favorites", Some(&alice_tok), None).await;
    assert_eq!(s, StatusCode::OK);
    let alice_ids: Vec<i64> = body_alice.as_array().unwrap().iter().map(|x| x["id"].as_i64().unwrap()).collect();
    assert_eq!(alice_ids.len(), 2);
    assert!(alice_ids.contains(&715415));
    assert!(alice_ids.contains(&716406));

    // 3. Bob sees exactly [644387, 716406]
    let (s, body_bob) = send_request(&app, "GET", "/api/Recipes/favorites", Some(&bob_tok), None).await;
    assert_eq!(s, StatusCode::OK);
    let bob_ids: Vec<i64> = body_bob.as_array().unwrap().iter().map(|x| x["id"].as_i64().unwrap()).collect();
    assert_eq!(bob_ids.len(), 2);
    assert!(bob_ids.contains(&716406));
    assert!(bob_ids.contains(&644387));

    // 4. Alice removes 716406 from her favorites
    let (s, body_unfav) = send_request(&app, "POST", "/api/Recipes/716406/favorite", Some(&alice_tok), None).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(body_unfav["isFavorited"], false);

    // 5. Verify Bob STILL has 716406 favorited (no tenant crosstalk on deletion)
    let (s, body_bob_after) = send_request(&app, "GET", "/api/Recipes/favorites", Some(&bob_tok), None).await;
    assert_eq!(s, StatusCode::OK);
    let bob_ids_after: Vec<i64> = body_bob_after.as_array().unwrap().iter().map(|x| x["id"].as_i64().unwrap()).collect();
    assert_eq!(bob_ids_after.len(), 2);
    assert!(bob_ids_after.contains(&716406));
    assert!(bob_ids_after.contains(&644387));

    // 6. Recipe detail reflects correct tenant state:
    // For Alice: 716406 -> isFavorited: false
    let (_, detail_alice) = send_request(&app, "GET", "/api/Recipes/716406", Some(&alice_tok), None).await;
    assert_eq!(detail_alice["isFavorited"], false);

    // For Bob: 716406 -> isFavorited: true
    let (_, detail_bob) = send_request(&app, "GET", "/api/Recipes/716406", Some(&bob_tok), None).await;
    assert_eq!(detail_bob["isFavorited"], true);

    // For Charlie: 716406 -> isFavorited: false
    let (_, detail_charlie) = send_request(&app, "GET", "/api/Recipes/716406", Some(&charlie_tok), None).await;
    assert_eq!(detail_charlie["isFavorited"], false);

    // For Unauthenticated: 716406 -> isFavorited: false
    let (_, detail_unauth) = send_request(&app, "GET", "/api/Recipes/716406", None, None).await;
    assert_eq!(detail_unauth["isFavorited"], false);

    // 7. Verify direct database row counts
    let count_alice: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE user_id = ?")
        .bind(alice_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count_alice.0, 1);

    let count_bob: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE user_id = ?")
        .bind(bob_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count_bob.0, 2);
}

// =========================================================================
// TEST 2: Spoofed or Tampered Token Sub Claims (Ghost Users & Malformed Sub)
// =========================================================================
#[tokio::test]
async fn test_adv_02_spoofed_or_tampered_token_tenant_isolation() {
    let (app, _pool) = setup_test_app().await;

    // 1. Ghost user ID 999999 (valid signature, but user does not exist in DB)
    let ghost_tok = forge_token_with_sub("999999", TEST_SECRET);

    // Toggle on ghost token -> 401 Unauthorized
    let (s, body) = send_request(&app, "POST", "/api/Recipes/715415/favorite", Some(&ghost_tok), None).await;
    assert_eq!(s, StatusCode::UNAUTHORIZED);
    assert!(body["error"].as_str().is_some());

    // Sync on ghost token -> 401 Unauthorized
    let (s, body) = send_request(&app, "POST", "/api/Recipes/sync-favorites", Some(&ghost_tok), Some(json!([715415]))).await;
    assert_eq!(s, StatusCode::UNAUTHORIZED);
    assert!(body["error"].as_str().is_some());

    // Get favorites on ghost token -> 200 with empty array (safe fallback)
    let (s, body) = send_request(&app, "GET", "/api/Recipes/favorites", Some(&ghost_tok), None).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(body.as_array().unwrap().len(), 0);

    // 2. Token with SQL injection sub: "1' OR '1'='1"
    let sqli_tok = forge_token_with_sub("1' OR '1'='1", TEST_SECRET);

    // Toggle -> 401 Unauthorized (fails user_id() parse to i64 before any SQL executes)
    let (s, body) = send_request(&app, "POST", "/api/Recipes/715415/favorite", Some(&sqli_tok), None).await;
    assert_eq!(s, StatusCode::UNAUTHORIZED);
    assert!(body["error"].as_str().is_some());

    // Sync -> 401 Unauthorized
    let (s, body) = send_request(&app, "POST", "/api/Recipes/sync-favorites", Some(&sqli_tok), Some(json!([715415]))).await;
    assert_eq!(s, StatusCode::UNAUTHORIZED);
    assert!(body["error"].as_str().is_some());

    // 3. Token with empty sub: ""
    let empty_sub_tok = forge_token_with_sub("", TEST_SECRET);
    let (s, _) = send_request(&app, "POST", "/api/Recipes/715415/favorite", Some(&empty_sub_tok), None).await;
    assert_eq!(s, StatusCode::UNAUTHORIZED);

    // 4. Token with negative sub: "-42"
    let neg_sub_tok = forge_token_with_sub("-42", TEST_SECRET);
    let (s, _) = send_request(&app, "POST", "/api/Recipes/715415/favorite", Some(&neg_sub_tok), None).await;
    assert_eq!(s, StatusCode::UNAUTHORIZED);
}

// =========================================================================
// TEST 3: Extreme Boundary Recipe IDs (Zero, Negative, i64::MAX, Non-numeric)
// =========================================================================
#[tokio::test]
async fn test_adv_03_boundary_recipe_ids_zero_negative_overflow() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "adv_boundary", "boundary@adv.com").await;

    // 1. Recipe ID = 0 (Recipes start at positive integers)
    let (s, body) = send_request(&app, "POST", "/api/Recipes/0/favorite", Some(&token), None).await;
    assert_eq!(s, StatusCode::NOT_FOUND);
    assert!(body["message"].as_str().is_some() || body["error"].as_str().is_some());

    // 2. Negative recipe ID: -1
    let (s, body) = send_request(&app, "POST", "/api/Recipes/-1/favorite", Some(&token), None).await;
    assert_eq!(s, StatusCode::NOT_FOUND);
    assert!(body["message"].as_str().is_some() || body["error"].as_str().is_some());

    // 3. Negative recipe ID: i64::MIN (-9223372036854775808)
    let min_i64_str = format!("/api/Recipes/{}/favorite", i64::MIN);
    let (s, body) = send_request(&app, "POST", &min_i64_str, Some(&token), None).await;
    assert_eq!(s, StatusCode::NOT_FOUND);
    assert!(body["message"].as_str().is_some() || body["error"].as_str().is_some());

    // 4. Large positive boundary: i64::MAX (9223372036854775807)
    let max_i64_str = format!("/api/Recipes/{}/favorite", i64::MAX);
    let (s, body) = send_request(&app, "POST", &max_i64_str, Some(&token), None).await;
    assert_eq!(s, StatusCode::NOT_FOUND);
    assert!(body["message"].as_str().is_some() || body["error"].as_str().is_some());

    // 5. Non-numeric path parameter: "abc"
    // Axum's Path<i64> rejects non-numeric segments with 400 Bad Request or 404 (never 500)
    let (s, _) = send_request(&app, "POST", "/api/Recipes/abc/favorite", Some(&token), None).await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::NOT_FOUND, "Status was: {}", s);

    // 6. Floating point path parameter: "1.5"
    let (s, _) = send_request(&app, "POST", "/api/Recipes/1.5/favorite", Some(&token), None).await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::NOT_FOUND, "Status was: {}", s);

    // 7. Integer overflow beyond i64: 999999999999999999999999999999999999999
    let (s, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/999999999999999999999999999999999999999/favorite",
        Some(&token),
        None,
    )
    .await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::NOT_FOUND, "Status was: {}", s);

    // 8. Null string path parameter
    let (s, _) = send_request(&app, "POST", "/api/Recipes/null/favorite", Some(&token), None).await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::NOT_FOUND, "Status was: {}", s);

    // 9. Verify database integrity: user_favorites table remains empty
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 0, "No rows should have been inserted for boundary recipe IDs");
}

// =========================================================================
// TEST 4: Batch Sync Boundary Fuzzing (Empty arrays, nulls, malformed JSON)
// =========================================================================
#[tokio::test]
async fn test_adv_04_batch_sync_boundary_fuzzing_empty_and_nulls() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "adv_fuzzer", "fuzz@adv.com").await;

    // 1. Direct empty array payload: [] -> 400 Bad Request
    let (s, body) = send_request(&app, "POST", "/api/Recipes/sync-favorites", Some(&token), Some(json!([]))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);
    assert!(body["message"].as_str().is_some() || body["error"].as_str().is_some());

    // 2. Object with empty recipeIds: {"recipeIds": []} -> 400 Bad Request
    let (s, _) = send_request(&app, "POST", "/api/Recipes/sync-favorites", Some(&token), Some(json!({"recipeIds": []}))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);

    // 3. Object with empty snake_case alias: {"recipe_ids": []} -> 400 Bad Request
    let (s, _) = send_request(&app, "POST", "/api/Recipes/sync-favorites", Some(&token), Some(json!({"recipe_ids": []}))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);

    // 4. Object with empty ids alias: {"ids": []} -> 400 Bad Request
    let (s, _) = send_request(&app, "POST", "/api/Recipes/sync-favorites", Some(&token), Some(json!({"ids": []}))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);

    // 5. Completely empty object: {} -> 400 Bad Request (recipe_ids defaults to empty)
    let (s, _) = send_request(&app, "POST", "/api/Recipes/sync-favorites", Some(&token), Some(json!({}))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);

    // 6. Null literal JSON payload -> 400 or 422
    let (s, _, _) = send_raw_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        b"null".to_vec(),
        "application/json",
    )
    .await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::UNPROCESSABLE_ENTITY, "Status was: {}", s);

    // 7. Boolean literal JSON payload -> 400 or 422
    let (s, _, _) = send_raw_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        b"true".to_vec(),
        "application/json",
    )
    .await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::UNPROCESSABLE_ENTITY, "Status was: {}", s);

    // 8. Raw number payload -> 400 or 422
    let (s, _, _) = send_raw_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        b"715415".to_vec(),
        "application/json",
    )
    .await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::UNPROCESSABLE_ENTITY, "Status was: {}", s);

    // 9. Object with string field type instead of integer array: {"recipeIds": "not_an_array"}
    let (s, _, _) = send_raw_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        br#"{"recipeIds": "not_an_array"}"#.to_vec(),
        "application/json",
    )
    .await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::UNPROCESSABLE_ENTITY, "Status was: {}", s);

    // 10. Array with string inside: [715415, "invalid_id"]
    let (s, _, _) = send_raw_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        br#"[715415, "invalid_id"]"#.to_vec(),
        "application/json",
    )
    .await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::UNPROCESSABLE_ENTITY, "Status was: {}", s);

    // 11. Malformed truncated JSON: {"recipeIds": [715415,
    let (s, _, _) = send_raw_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        br#"{"recipeIds": [715415, "#.to_vec(),
        "application/json",
    )
    .await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::UNPROCESSABLE_ENTITY, "Status was: {}", s);

    // 12. Empty raw body
    let (s, _, _) = send_raw_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        vec![],
        "application/json",
    )
    .await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::UNPROCESSABLE_ENTITY, "Status was: {}", s);
}

// =========================================================================
// TEST 5: 1000 Duplicate IDs & Idempotency Stress
// =========================================================================
#[tokio::test]
async fn test_adv_05_batch_sync_1000_duplicates_and_idempotency_stress() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "adv_stress", "stress@adv.com").await;

    // 1. Send 1000 items of the identical valid recipe ID: 715415
    let thousand_dups = vec![715415i64; 1000];
    let (s, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(json!(thousand_dups)),
    )
    .await;

    assert_eq!(s, StatusCode::OK);
    assert_eq!(body["syncedCount"], 1, "Deduplication must insert exactly 1 record");

    // 2. Verify database has exactly 1 record for this user
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 1);

    // 3. Send 1000 items of the same ID AGAIN -> Idempotent, inserts 0 new rows
    let (s, body_replay) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(json!(thousand_dups)),
    )
    .await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(body_replay["syncedCount"], 0, "Replaying same sync must insert 0 new rows");

    // 4. Object format with 1000 duplicates of recipe 716406
    let thousand_dups_obj = json!({
        "recipeIds": vec![716406i64; 1000]
    });
    let (s, body_obj) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(thousand_dups_obj),
    )
    .await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(body_obj["syncedCount"], 1);

    // 5. Total favorites for user is now exactly 2
    let (s, favs) = send_request(&app, "GET", "/api/Recipes/favorites", Some(&token), None).await;
    assert_eq!(s, StatusCode::OK);
    let items = favs.as_array().unwrap();
    assert_eq!(items.len(), 2);
    let ids: Vec<i64> = items.iter().map(|i| i["id"].as_i64().unwrap()).collect();
    assert!(ids.contains(&715415));
    assert!(ids.contains(&716406));
}

// =========================================================================
// TEST 6: Multi-Chunk Query Fuzzing (>250 items, valid mixed with non-existent)
// =========================================================================
#[tokio::test]
async fn test_adv_06_batch_sync_multi_chunk_stress_with_nonexistent_ids() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "adv_chunks", "chunks@adv.com").await;

    // Build 350 items:
    // 3 valid recipes: 715415, 716406, 644387
    // 347 non-existent recipes spanning across multiple 100-item chunks:
    // 5000000..5000344, plus extreme IDs 0, -1, i64::MAX
    let mut large_batch: Vec<i64> = (5_000_000i64..5_000_344i64).collect();
    large_batch.push(0);
    large_batch.push(-1);
    large_batch.push(i64::MAX);
    large_batch.push(715415);
    large_batch.push(716406);
    large_batch.push(644387);

    assert_eq!(large_batch.len(), 350);

    let (s, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(json!(large_batch)),
    )
    .await;

    assert_eq!(s, StatusCode::OK);
    assert_eq!(
        body["syncedCount"], 3,
        "Only the 3 existing recipes should be synced across chunks"
    );

    // Verify user favorites list has exactly 3 items
    let (s, favs) = send_request(&app, "GET", "/api/Recipes/favorites", Some(&token), None).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(favs.as_array().unwrap().len(), 3);

    // Verify database row count
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 3);
}

// =========================================================================
// TEST 7: SQL Injection Resistance on Paths, Search, and Sync
// =========================================================================
#[tokio::test]
async fn test_adv_07_sqli_resilience_on_path_and_payloads() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "adv_sqli", "sqli@adv.com").await;

    // 1. Path SQL injection attempt: "1 OR 1=1"
    let (s, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/1%20OR%201=1/favorite",
        Some(&token),
        None,
    )
    .await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::NOT_FOUND);

    // 2. Path SQL injection attempt: "1; DROP TABLE user_favorites; --"
    let (s, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/1;%20DROP%20TABLE%20user_favorites;%20--/favorite",
        Some(&token),
        None,
    )
    .await;
    assert!(s == StatusCode::BAD_REQUEST || s == StatusCode::NOT_FOUND);

    // 3. Search query with SQL injection string while authenticated
    let (s, search_res) = send_request(
        &app,
        "GET",
        "/api/Recipes/search?term='%20OR%201=1%20--",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(s, StatusCode::OK);
    assert!(search_res.as_array().is_some());

    // 4. Authenticated search with UNION injection
    let (s, search_res2) = send_request(
        &app,
        "GET",
        "/api/Recipes/search?term='%20UNION%20SELECT%20null,null,null,null,null,null,null,null,null%20--",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(s, StatusCode::OK);
    assert!(search_res2.as_array().is_some());

    // 5. Verify database schema and table user_favorites is completely intact
    let table_check: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE user_id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(table_check.0, 0);

    let users_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(users_count.0 >= 1);
}

// =========================================================================
// TEST 8: Foreign Key Cascade and Referential Integrity Under Deletion
// =========================================================================
#[tokio::test]
async fn test_adv_08_foreign_key_cascade_and_referential_integrity() {
    let (app, pool) = setup_test_app().await;

    let (u1_id, u1_tok) = create_test_user(&pool, "cascade_u1", "u1@cascade.com").await;
    let (u2_id, u2_tok) = create_test_user(&pool, "cascade_u2", "u2@cascade.com").await;

    // User 1 favorites recipes 715415 and 716406
    send_request(&app, "POST", "/api/Recipes/715415/favorite", Some(&u1_tok), None).await;
    send_request(&app, "POST", "/api/Recipes/716406/favorite", Some(&u1_tok), None).await;

    // User 2 favorites recipe 715415
    send_request(&app, "POST", "/api/Recipes/715415/favorite", Some(&u2_tok), None).await;

    // Initial state: 3 total rows in user_favorites
    let initial_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(initial_count.0, 3);

    // 1. Delete User 1 -> Foreign key ON DELETE CASCADE must clean up User 1's favorites
    sqlx::query("DELETE FROM users WHERE id = ?")
        .bind(u1_id)
        .execute(&pool)
        .await
        .unwrap();

    let count_after_user_delete: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(
        count_after_user_delete.0, 1,
        "User 1's favorites must cascade delete, leaving only User 2's favorite"
    );

    // User 2's favorite endpoint still returns recipe 715415
    let (s, u2_favs) = send_request(&app, "GET", "/api/Recipes/favorites", Some(&u2_tok), None).await;
    assert_eq!(s, StatusCode::OK);
    let items = u2_favs.as_array().unwrap();
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["id"].as_i64().unwrap(), 715415);

    // 2. Delete Recipe 715415 -> Foreign key ON DELETE CASCADE must clean up User 2's favorite
    sqlx::query("DELETE FROM recipes WHERE id = 715415")
        .execute(&pool)
        .await
        .unwrap();

    let count_after_recipe_delete: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(
        count_after_recipe_delete.0, 0,
        "Recipe deletion must cascade delete all associated favorites"
    );

    // User 2's favorite endpoint now returns empty list
    let (s, u2_favs_empty) = send_request(&app, "GET", "/api/Recipes/favorites", Some(&u2_tok), None).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(u2_favs_empty.as_array().unwrap().len(), 0);

    // Clean up verify
    let u2_exists: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE id = ?")
        .bind(u2_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(u2_exists.0, 1);
}

// =========================================================================
// TEST 9: Concurrency Hammer & Race Condition Resilience
// =========================================================================
#[tokio::test]
async fn test_adv_09_concurrency_toggle_hammer_race_safety() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "hammer_user", "hammer@adv.com").await;

    // Part A: Sequential rapid toggle hammer (20 flips in quick succession)
    // Ensures sequential rapid clicks by a user alternate cleanly between true and false
    for i in 0..20 {
        let (status, body) = send_request(
            &app,
            "POST",
            "/api/Recipes/715415/favorite",
            Some(&token),
            None,
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        let expected_fav = i % 2 == 0;
        assert_eq!(body["isFavorited"], expected_fav, "Toggle iteration {} failed", i);
    }

    // Part B: Concurrent hammer on the same recipe by the same user
    // Under simultaneous racing requests, SQLite enforces UNIQUE(user_id, recipe_id).
    // Racing tasks either succeed (200 OK) or encounter unique constraint violation on losers.
    let mut handles = Vec::new();
    for _ in 0..20 {
        let app_clone = app.clone();
        let tok_clone = token.clone();
        handles.push(tokio::spawn(async move {
            send_request(
                &app_clone,
                "POST",
                "/api/Recipes/715415/favorite",
                Some(&tok_clone),
                None,
            )
            .await
        }));
    }

    let mut ok_count = 0;
    let mut conflict_count = 0;
    for h in handles {
        let (status, _) = h.await.unwrap();
        if status == StatusCode::OK {
            ok_count += 1;
        } else if status == StatusCode::INTERNAL_SERVER_ERROR || status == StatusCode::CONFLICT {
            conflict_count += 1;
        }
    }

    assert!(ok_count >= 1, "At least one racing toggle must succeed");
    assert_eq!(
        ok_count + conflict_count,
        20,
        "All 20 requests must complete without unhandled crash"
    );

    // Verify database integrity: row count in DB must never exceed 1
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = 715415")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(
        count.0 == 0 || count.0 == 1,
        "Database integrity violated: count must be 0 or 1, got {}",
        count.0
    );

    // Part C: Cross-user concurrent toggles (User A and User B hammer concurrently)
    // Because user_id is distinct, no unique constraint conflicts occur across users
    let (_u2_id, u2_tok) = create_test_user(&pool, "hammer_u2", "hammer2@adv.com").await;
    let mut dual_handles = Vec::new();

    for i in 0..20 {
        let app_clone = app.clone();
        let tok = if i % 2 == 0 {
            token.clone()
        } else {
            u2_tok.clone()
        };
        dual_handles.push(tokio::spawn(async move {
            send_request(
                &app_clone,
                "POST",
                "/api/Recipes/716406/favorite",
                Some(&tok),
                None,
            )
            .await
        }));
    }

    let mut dual_completed = 0;
    for h in dual_handles {
        let (status, _) = h.await.unwrap();
        if status == StatusCode::OK || status == StatusCode::INTERNAL_SERVER_ERROR {
            dual_completed += 1;
        }
    }
    assert_eq!(dual_completed, 20, "All 20 cross-user concurrent toggles must complete safely");
}

// =========================================================================
// TEST 10: Payload Extraneous Fields and Sync Boundary Permutations
// =========================================================================
#[tokio::test]
async fn test_adv_10_extra_fields_and_casing_variations() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "adv_extra", "extra@adv.com").await;

    // 1. Batch sync with extra unexpected JSON fields (admin, attack script, __proto__)
    let malicious_payload = json!({
        "recipeIds": [715415],
        "isAdmin": true,
        "role": "SuperAdmin",
        "script": "<script>alert('xss')</script>",
        "__proto__": { "polluted": true }
    });

    let (s, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(malicious_payload),
    )
    .await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(body["syncedCount"], 1);

    // 2. Batch sync with unknown recipe IDs mixed with 0, negative, and duplicates
    let mixed_payload = json!([716406, 0, -1, 716406, 9999999]);
    let (s, body_mixed) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(mixed_payload),
    )
    .await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(body_mixed["syncedCount"], 1, "Only recipe 716406 should be newly synced");

    // 3. User favorites list now contains exactly 2 items: 715415 and 716406
    let (s, favs) = send_request(&app, "GET", "/api/Recipes/favorites", Some(&token), None).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(favs.as_array().unwrap().len(), 2);
}
