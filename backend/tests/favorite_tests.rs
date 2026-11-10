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

#[tokio::test]
async fn test_01_toggle_favorite_add_and_remove_flow() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "fav_user_1", "fav1@bepviet.vn").await;

    // 1. Initial toggle -> Add to favorites
    let (status, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some(&token),
        None,
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["isFavorited"], true);
    assert!(
        body["message"].as_str().unwrap().contains("added")
            || body["message"].as_str().unwrap().contains("yêu thích"),
        "Message should indicate addition: {}",
        body["message"]
    );

    // Verify row in user_favorites table
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = 715415",
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(count.0, 1, "Recipe should be present in database");

    // 2. Second toggle -> Remove from favorites
    let (status, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some(&token),
        None,
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["isFavorited"], false);
    assert!(
        body["message"].as_str().unwrap().contains("removed")
            || body["message"].as_str().unwrap().contains("bỏ"),
        "Message should indicate removal: {}",
        body["message"]
    );

    // Verify row removed from database
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM user_favorites WHERE user_id = ? AND recipe_id = 715415",
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(count.0, 0, "Recipe should be deleted from database");
}

#[tokio::test]
async fn test_02_toggle_favorite_unauthenticated_and_invalid_token() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, _token) = create_test_user(&pool, "fav_user_2", "fav2@bepviet.vn").await;

    // 1. Unauthenticated request without token
    let (status, body) = send_request(&app, "POST", "/api/Recipes/715415/favorite", None, None).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"], "Unauthorized");

    // 2. Invalid bearer token
    let (status, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some("invalid_jwt_garbage_token"),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"], "Unauthorized");

    // 3. Expired token (negative expiration)
    let expired_token = generate_jwt(999, "exp@bepviet.vn", "User", TEST_SECRET, false, 0).unwrap();
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some(&expired_token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn test_03_toggle_favorite_nonexistent_recipe() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "fav_user_3", "fav3@bepviet.vn").await;

    // Non-existent recipe ID
    let (status, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/99999999/favorite",
        Some(&token),
        None,
    )
    .await;

    assert_eq!(status, StatusCode::NOT_FOUND);
    assert!(
        body["message"].as_str().is_some() || body["error"].as_str().is_some(),
        "Should return 404 error payload"
    );
}

#[tokio::test]
async fn test_04_get_favorites_list_authenticated_and_unauthenticated() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "fav_user_4", "fav4@bepviet.vn").await;

    // 1. Unauthenticated GET -> returns empty list []
    let (status, body) = send_request(&app, "GET", "/api/Recipes/favorites", None, None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body.as_array().unwrap().len(), 0);

    // 2. User initially has no favorites
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes/favorites", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body.as_array().unwrap().len(), 0);

    // 3. Add two favorites: 715415 and 716406
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/716406/favorite",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    // 4. Authenticated GET -> returns 2 items with isFavorited = true
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes/favorites", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert_eq!(items.len(), 2);

    let ids: Vec<i64> = items.iter().map(|item| item["id"].as_i64().unwrap()).collect();
    assert!(ids.contains(&715415));
    assert!(ids.contains(&716406));

    for item in items {
        assert_eq!(item["isFavorited"], true);
        assert!(item["title"].as_str().is_some());
        assert!(item["imageUrl"].as_str().is_some());
        assert!(item["category"].as_str().is_some());
        assert!(item["ingredientNames"].as_array().is_some());
    }
}

#[tokio::test]
async fn test_05_multi_user_isolation() {
    let (app, pool) = setup_test_app().await;
    let (_user_a_id, token_a) = create_test_user(&pool, "user_a", "usera@bepviet.vn").await;
    let (_user_b_id, token_b) = create_test_user(&pool, "user_b", "userb@bepviet.vn").await;

    // User A favorites recipe 715415
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some(&token_a),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    // User B favorites recipe 716406
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/716406/favorite",
        Some(&token_b),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    // User A only sees 715415
    let (status, body_a) =
        send_request(&app, "GET", "/api/Recipes/favorites", Some(&token_a), None).await;
    assert_eq!(status, StatusCode::OK);
    let items_a = body_a.as_array().unwrap();
    assert_eq!(items_a.len(), 1);
    assert_eq!(items_a[0]["id"].as_i64().unwrap(), 715415);

    // User B only sees 716406
    let (status, body_b) =
        send_request(&app, "GET", "/api/Recipes/favorites", Some(&token_b), None).await;
    assert_eq!(status, StatusCode::OK);
    let items_b = body_b.as_array().unwrap();
    assert_eq!(items_b.len(), 1);
    assert_eq!(items_b[0]["id"].as_i64().unwrap(), 716406);

    // User A removes 715415
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some(&token_a),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    // User A list is now empty
    let (_, body_a_after) =
        send_request(&app, "GET", "/api/Recipes/favorites", Some(&token_a), None).await;
    assert_eq!(body_a_after.as_array().unwrap().len(), 0);

    // User B list still has 716406 unchanged
    let (_, body_b_after) =
        send_request(&app, "GET", "/api/Recipes/favorites", Some(&token_b), None).await;
    assert_eq!(body_b_after.as_array().unwrap().len(), 1);
    assert_eq!(body_b_after.as_array().unwrap()[0]["id"].as_i64().unwrap(), 716406);
}

#[tokio::test]
async fn test_06_batch_sync_offline_favorites_array_and_idempotency() {
    let (app, pool) = setup_test_app().await;
    let (user_id, token) = create_test_user(&pool, "sync_user_1", "sync1@bepviet.vn").await;

    // 1. Batch sync using direct array: [715415, 716406]
    let payload = json!([715415, 716406]);
    let (status, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(payload),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["syncedCount"], 2);

    // 2. Call sync again with duplicate IDs and already-synced IDs: [715415, 716406, 715415]
    let payload_dup = json!([715415, 716406, 715415]);
    let (status, body_dup) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(payload_dup),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_dup["syncedCount"], 0, "Idempotent sync should insert 0 new rows");

    // 3. Verify total row count in database for this user is exactly 2
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM user_favorites WHERE user_id = ?",
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(count.0, 2);
}

#[tokio::test]
async fn test_07_batch_sync_offline_favorites_object_payload() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "sync_user_2", "sync2@bepviet.vn").await;

    // 1. Sync with object payload: {"recipeIds": [644387, 715446]}
    let payload = json!({
        "recipeIds": [644387, 715446]
    });
    let (status, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(payload),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["syncedCount"], 2);

    // 2. Sync with snake_case alias payload: {"recipe_ids": [782601]}
    let payload_alias = json!({
        "recipe_ids": [782601]
    });
    let (status, body_alias) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(payload_alias),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_alias["syncedCount"], 1);

    // 3. User favorites list now contains all 3 synced recipes
    let (status, favs) =
        send_request(&app, "GET", "/api/Recipes/favorites", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(favs.as_array().unwrap().len(), 3);
}

#[tokio::test]
async fn test_08_batch_sync_empty_and_unauthenticated_rejection() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "sync_user_3", "sync3@bepviet.vn").await;

    // 1. Unauthenticated request -> 401 Unauthorized
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        None,
        Some(json!([715415])),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);

    // 2. Empty array payload -> 400 Bad Request
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(json!([])),
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);

    // 3. Empty object payload -> 400 Bad Request
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(json!({ "recipeIds": [] })),
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn test_09_batch_sync_with_nonexistent_recipe_ids() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "sync_user_4", "sync4@bepviet.vn").await;

    // Payload contains 1 valid recipe ID and 2 non-existent IDs
    let payload = json!([715415, 9999991, 9999992]);
    let (status, body) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(payload),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["syncedCount"], 1, "Only the 1 existing recipe should be synced");

    let (_, favs) =
        send_request(&app, "GET", "/api/Recipes/favorites", Some(&token), None).await;
    let items = favs.as_array().unwrap();
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["id"].as_i64().unwrap(), 715415);
}

#[tokio::test]
async fn test_10_cross_endpoint_integration_recipes_and_search() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "cross_user", "cross@bepviet.vn").await;

    // 1. Before favoriting: GET /api/Recipes/715415 has isFavorited = false
    let (status, detail_before) =
        send_request(&app, "GET", "/api/Recipes/715415", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(detail_before["isFavorited"], false);

    // 2. Favorite recipe 715415
    let (status, toggle_res) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(toggle_res["isFavorited"], true);

    // 3. GET /api/Recipes/715415 reflects isFavorited = true
    let (status, detail_after) =
        send_request(&app, "GET", "/api/Recipes/715415", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(detail_after["isFavorited"], true);

    // 4. GET /api/Recipes listing reflects isFavorited = true for 715415
    let (status, list_body) =
        send_request(&app, "GET", "/api/Recipes", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    let items = list_body.as_array().unwrap();
    let r_715415 = items.iter().find(|i| i["id"].as_i64().unwrap() == 715415).unwrap();
    assert_eq!(r_715415["isFavorited"], true);
    let r_716406 = items.iter().find(|i| i["id"].as_i64().unwrap() == 716406).unwrap();
    assert_eq!(r_716406["isFavorited"], false);

    // 5. GET /api/Recipes/search reflects isFavorited = true
    let (status, search_body) = send_request(
        &app,
        "GET",
        "/api/Recipes/search?term=gà",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let search_items = search_body.as_array().unwrap();
    let searched = search_items.iter().find(|i| i["id"].as_i64().unwrap() == 715415).unwrap();
    assert_eq!(searched["isFavorited"], true);

    // 6. Unfavorite recipe 715415
    let (status, toggle_off) = send_request(
        &app,
        "POST",
        "/api/Recipes/715415/favorite",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(toggle_off["isFavorited"], false);

    // 7. Verify GET /api/Recipes/715415 reflects isFavorited = false
    let (_, detail_unfav) =
        send_request(&app, "GET", "/api/Recipes/715415", Some(&token), None).await;
    assert_eq!(detail_unfav["isFavorited"], false);
}

#[tokio::test]
async fn test_11_route_aliases_matrix() {
    let (app, pool) = setup_test_app().await;
    let (_user_id, token) = create_test_user(&pool, "alias_user", "alias@bepviet.vn").await;

    // 1. Lowercase toggle alias: POST /api/recipes/715415/favorite
    let (status, body) = send_request(
        &app,
        "POST",
        "/api/recipes/715415/favorite",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["isFavorited"], true);

    // 2. Lowercase favorites alias: GET /api/recipes/favorites
    let (status, body) =
        send_request(&app, "GET", "/api/recipes/favorites", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["id"].as_i64().unwrap(), 715415);

    // 3. Lowercase sync alias: POST /api/recipes/sync-favorites
    let (status, body) = send_request(
        &app,
        "POST",
        "/api/recipes/sync-favorites",
        Some(&token),
        Some(json!([716406])),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["syncedCount"], 1);

    // 4. Verify list now has 2 items via PascalCase GET /api/Recipes/favorites
    let (status, body_pascal) =
        send_request(&app, "GET", "/api/Recipes/favorites", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_pascal.as_array().unwrap().len(), 2);
}
