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

// ----------------------------------------------------------------------------
// 1. ADD SINGLE DETAILED INGREDIENT (name, amount, unit, notes) -> 200/201
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_01_add_single_detailed_ingredient() {
    let (app, pool) = setup_test_app().await;
    let (_uid, token) = create_test_user(&pool, "chef_detail", "detail@bepviet.vn").await;

    let payload = json!({
        "name": "thịt ba chỉ",
        "amount": 300.0,
        "unit": "g",
        "notes": "Trong ngăn đông"
    });

    let (status, body) = send_request(&app, "POST", "/api/pantry", Some(&token), Some(payload)).await;

    assert!(
        status == StatusCode::CREATED || status == StatusCode::OK,
        "Expected 201 Created or 200 OK, got {}",
        status
    );
    assert!(body["message"].as_str().unwrap().contains("thành công"));
    assert_eq!(body["item"]["name"], "thịt ba chỉ");
    assert_eq!(body["item"]["amount"], 300.0);
    assert_eq!(body["item"]["unit"], "g");
    assert!(body["item"]["id"].as_i64().is_some());
    assert!(body["item"]["createdAt"].as_str().is_some());
}

// ----------------------------------------------------------------------------
// 2. ADD SINGLE SIMPLE INGREDIENT (name only) -> 200/201
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_02_add_single_simple_ingredient() {
    let (app, pool) = setup_test_app().await;
    let (_uid, token) = create_test_user(&pool, "chef_simple", "simple@bepviet.vn").await;

    let payload = json!({
        "name": "hành lá"
    });

    let (status, body) = send_request(&app, "POST", "/api/pantry", Some(&token), Some(payload)).await;

    assert!(
        status == StatusCode::CREATED || status == StatusCode::OK,
        "Expected 201 Created or 200 OK, got {}",
        status
    );
    assert_eq!(body["item"]["name"], "hành lá");
    assert_eq!(body["item"]["amount"], 1.0); // default amount
}

// ----------------------------------------------------------------------------
// 3. ADD BATCH INGREDIENTS (names array & raw list) -> 200/201
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_03_add_batch_ingredients() {
    let (app, pool) = setup_test_app().await;
    let (uid, token) = create_test_user(&pool, "chef_batch", "batch@bepviet.vn").await;

    // Batch via object with `names`
    let payload = json!({
        "names": ["thịt ba chỉ", "hành lá", "gừng"]
    });

    let (status, body) = send_request(&app, "POST", "/api/pantry", Some(&token), Some(payload)).await;

    assert!(
        status == StatusCode::CREATED || status == StatusCode::OK,
        "Expected 201 Created or 200 OK, got {}",
        status
    );
    assert!(body["message"].as_str().unwrap().contains("thành công"));
    assert_eq!(body["count"], 3);

    // Verify all 3 in database for this user
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(uid)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 3);

    // Batch via raw array of strings
    let raw_payload = json!(["tiêu xay", "tỏi"]);
    let (status2, body2) = send_request(&app, "POST", "/api/pantry", Some(&token), Some(raw_payload)).await;
    assert!(status2 == StatusCode::CREATED || status2 == StatusCode::OK);
    assert_eq!(body2["count"], 2);

    let count2: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(uid)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count2.0, 5);
}

// ----------------------------------------------------------------------------
// 4. GET PANTRY LIST RETURNS items AND ingredientNames ARRAY
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_04_get_pantry_list_returns_items_and_ingredient_names() {
    let (app, pool) = setup_test_app().await;
    let (_uid, token) = create_test_user(&pool, "chef_list", "list@bepviet.vn").await;

    // Add items
    send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token),
        Some(json!({ "name": "thịt bò", "amount": 500.0, "unit": "g" })),
    )
    .await;

    send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token),
        Some(json!({ "name": "cà chua", "amount": 3.0, "unit": "quả" })),
    )
    .await;

    let (status, body) = send_request(&app, "GET", "/api/pantry", Some(&token), None).await;

    assert_eq!(status, StatusCode::OK);
    let items = body["items"].as_array().expect("items should be an array");
    assert_eq!(items.len(), 2);

    let ingredient_names = body["ingredientNames"]
        .as_array()
        .expect("ingredientNames should be an array");
    assert_eq!(ingredient_names.len(), 2);

    let names: Vec<&str> = ingredient_names.iter().map(|v| v.as_str().unwrap()).collect();
    assert!(names.contains(&"thịt bò"));
    assert!(names.contains(&"cà chua"));
}

// ----------------------------------------------------------------------------
// 5. MULTI-TENANT ISOLATION: USER B CANNOT SEE USER A'S PANTRY ITEMS
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_05_multi_tenant_isolation() {
    let (app, pool) = setup_test_app().await;
    let (_user_a_id, token_a) = create_test_user(&pool, "user_alpha", "alpha@bepviet.vn").await;
    let (_user_b_id, token_b) = create_test_user(&pool, "user_beta", "beta@bepviet.vn").await;

    // User A adds items
    send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token_a),
        Some(json!({ "name": "thịt cừu", "amount": 1.0, "unit": "kg" })),
    )
    .await;

    send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token_a),
        Some(json!({ "name": "rượu vang", "amount": 250.0, "unit": "ml" })),
    )
    .await;

    // User B queries pantry -> Should be empty!
    let (status_b, body_b) = send_request(&app, "GET", "/api/pantry", Some(&token_b), None).await;
    assert_eq!(status_b, StatusCode::OK);
    assert_eq!(body_b["items"].as_array().unwrap().len(), 0);
    assert_eq!(body_b["ingredientNames"].as_array().unwrap().len(), 0);

    // User B adds their own item
    send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token_b),
        Some(json!({ "name": "đậu phụ", "amount": 4.0, "unit": "bìa" })),
    )
    .await;

    let (_, body_b_after) = send_request(&app, "GET", "/api/pantry", Some(&token_b), None).await;
    assert_eq!(body_b_after["items"].as_array().unwrap().len(), 1);
    assert_eq!(body_b_after["items"][0]["name"], "đậu phụ");

    // User A queries again -> User A still sees their 2 items, and NOT User B's item
    let (_, body_a) = send_request(&app, "GET", "/api/pantry", Some(&token_a), None).await;
    assert_eq!(body_a["items"].as_array().unwrap().len(), 2);
    let names_a: Vec<&str> = body_a["ingredientNames"]
        .as_array()
        .unwrap()
        .iter()
        .map(|v| v.as_str().unwrap())
        .collect();
    assert!(!names_a.contains(&"đậu phụ"));
}

// ----------------------------------------------------------------------------
// 6. UPDATE PANTRY ITEM: USER A UPDATES OWN ITEM (200), USER B CANNOT (404)
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_06_update_pantry_item_and_isolation() {
    let (app, pool) = setup_test_app().await;
    let (_uid_a, token_a) = create_test_user(&pool, "chef_up_a", "up_a@bepviet.vn").await;
    let (_uid_b, token_b) = create_test_user(&pool, "chef_up_b", "up_b@bepviet.vn").await;

    // User A adds an item
    let (_, add_body) = send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token_a),
        Some(json!({ "name": "thịt ba chỉ", "amount": 300.0, "unit": "g" })),
    )
    .await;
    let item_id = add_body["item"]["id"].as_i64().unwrap();

    // User B attempts to update User A's item -> 404 Not Found
    let (status_b_up, _) = send_request(
        &app,
        "PUT",
        &format!("/api/pantry/{}", item_id),
        Some(&token_b),
        Some(json!({ "name": "hacker bacon", "amount": 999.0 })),
    )
    .await;
    assert_eq!(status_b_up, StatusCode::NOT_FOUND);

    // User A updates own item -> 200 OK
    let (status_a_up, body_a_up) = send_request(
        &app,
        "PUT",
        &format!("/api/pantry/{}", item_id),
        Some(&token_a),
        Some(json!({
            "name": "thịt ba chỉ tươi",
            "amount": 400.0,
            "unit": "g",
            "notes": "Đã chuyển xuống ngăn mát"
        })),
    )
    .await;

    assert_eq!(status_a_up, StatusCode::OK);
    assert!(body_a_up["message"].as_str().unwrap().contains("thành công"));
    assert_eq!(body_a_up["item"]["name"], "thịt ba chỉ tươi");
    assert_eq!(body_a_up["item"]["amount"], 400.0);

    // Verify update persisted in GET
    let (_, get_body) = send_request(&app, "GET", "/api/pantry", Some(&token_a), None).await;
    assert_eq!(get_body["items"][0]["name"], "thịt ba chỉ tươi");
    assert_eq!(get_body["items"][0]["amount"], 400.0);
}

// ----------------------------------------------------------------------------
// 7. DELETE ITEM BY ID (200), DELETING NON-EXISTENT OR OTHER USER'S ITEM (404)
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_07_delete_item_by_id_and_security() {
    let (app, pool) = setup_test_app().await;
    let (_uid_a, token_a) = create_test_user(&pool, "del_a", "del_a@bepviet.vn").await;
    let (_uid_b, token_b) = create_test_user(&pool, "del_b", "del_b@bepviet.vn").await;

    // User A adds an item
    let (_, add_body) = send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token_a),
        Some(json!({ "name": "nấm hương", "amount": 100.0, "unit": "g" })),
    )
    .await;
    let item_id = add_body["item"]["id"].as_i64().unwrap();

    // User B tries to delete User A's item -> 404 Not Found
    let (status_b_del, _) = send_request(
        &app,
        "DELETE",
        &format!("/api/pantry/{}", item_id),
        Some(&token_b),
        None,
    )
    .await;
    assert_eq!(status_b_del, StatusCode::NOT_FOUND);

    // Deleting non-existent ID -> 404 Not Found
    let (status_fake, _) = send_request(
        &app,
        "DELETE",
        "/api/pantry/999999",
        Some(&token_a),
        None,
    )
    .await;
    assert_eq!(status_fake, StatusCode::NOT_FOUND);

    // User A deletes own item -> 200 OK
    let (status_a_del, body_a_del) = send_request(
        &app,
        "DELETE",
        &format!("/api/pantry/{}", item_id),
        Some(&token_a),
        None,
    )
    .await;
    assert_eq!(status_a_del, StatusCode::OK);
    assert!(body_a_del["message"].as_str().unwrap().contains("xóa"));

    // Verify item is gone
    let (_, get_body) = send_request(&app, "GET", "/api/pantry", Some(&token_a), None).await;
    assert_eq!(get_body["items"].as_array().unwrap().len(), 0);
}

// ----------------------------------------------------------------------------
// 8. DELETE ITEM BY QUERY PARAM `?name=...`
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_08_delete_item_by_name_query() {
    let (app, pool) = setup_test_app().await;
    let (_uid, token) = create_test_user(&pool, "del_name_user", "del_name@bepviet.vn").await;

    // Add items
    send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token),
        Some(json!({ "names": ["cà rốt", "khoai tây", "hành tây"] })),
    )
    .await;

    // Delete "khoai tây" by query param ?name=khoai tây
    let (status_del, body_del) = send_request(
        &app,
        "DELETE",
        "/api/pantry?name=khoai%20t%C3%A2y",
        Some(&token),
        None,
    )
    .await;

    assert_eq!(status_del, StatusCode::OK);
    assert!(body_del["message"].as_str().unwrap().contains("xóa"));

    // Verify remaining items
    let (_, body_after) = send_request(&app, "GET", "/api/pantry", Some(&token), None).await;
    let names: Vec<&str> = body_after["ingredientNames"]
        .as_array()
        .unwrap()
        .iter()
        .map(|v| v.as_str().unwrap())
        .collect();
    assert_eq!(names.len(), 2);
    assert!(!names.contains(&"khoai tây"));
    assert!(names.contains(&"cà rốt"));
    assert!(names.contains(&"hành tây"));

    // Delete non-existent name -> 404
    let (status_nonexistent, _) = send_request(
        &app,
        "DELETE",
        "/api/pantry?name=khong_ton_tai",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status_nonexistent, StatusCode::NOT_FOUND);
}

// ----------------------------------------------------------------------------
// 9. CLEAR PANTRY: DELETES ONLY CURRENT USER'S ITEMS
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_09_clear_pantry_isolation() {
    let (app, pool) = setup_test_app().await;
    let (_uid_a, token_a) = create_test_user(&pool, "clear_a", "clear_a@bepviet.vn").await;
    let (_uid_b, token_b) = create_test_user(&pool, "clear_b", "clear_b@bepviet.vn").await;

    // Both users add items
    send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token_a),
        Some(json!({ "names": ["tôm", "mực", "cua"] })),
    )
    .await;

    send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token_b),
        Some(json!({ "names": ["gà", "vịt"] })),
    )
    .await;

    // User A clears their pantry
    let (status_clear, body_clear) = send_request(&app, "DELETE", "/api/pantry", Some(&token_a), None).await;
    assert_eq!(status_clear, StatusCode::OK);
    assert!(body_clear["message"].as_str().unwrap().contains("dọn sạch"));
    assert_eq!(body_clear["deletedCount"], 3);

    // Verify User A pantry is empty
    let (_, body_a) = send_request(&app, "GET", "/api/pantry", Some(&token_a), None).await;
    assert_eq!(body_a["items"].as_array().unwrap().len(), 0);

    // Verify User B pantry remains completely untouched
    let (_, body_b) = send_request(&app, "GET", "/api/pantry", Some(&token_b), None).await;
    assert_eq!(body_b["items"].as_array().unwrap().len(), 2);
    assert_eq!(body_b["ingredientNames"].as_array().unwrap().len(), 2);
}

// ----------------------------------------------------------------------------
// 10. UNAUTHENTICATED REQUESTS RETURN 401 UNAUTHORIZED
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_10_unauthenticated_requests_return_401() {
    let (app, _pool) = setup_test_app().await;

    // GET /api/pantry without token
    let (s1, b1) = send_request(&app, "GET", "/api/pantry", None, None).await;
    assert_eq!(s1, StatusCode::UNAUTHORIZED);
    assert_eq!(b1["error"], "Unauthorized");

    // POST /api/pantry without token
    let (s2, b2) = send_request(
        &app,
        "POST",
        "/api/pantry",
        None,
        Some(json!({ "name": "thịt" })),
    )
    .await;
    assert_eq!(s2, StatusCode::UNAUTHORIZED);
    assert_eq!(b2["error"], "Unauthorized");

    // PUT /api/pantry/1 without token
    let (s3, _) = send_request(
        &app,
        "PUT",
        "/api/pantry/1",
        None,
        Some(json!({ "name": "thịt" })),
    )
    .await;
    assert_eq!(s3, StatusCode::UNAUTHORIZED);

    // DELETE /api/pantry/1 without token
    let (s4, _) = send_request(&app, "DELETE", "/api/pantry/1", None, None).await;
    assert_eq!(s4, StatusCode::UNAUTHORIZED);

    // DELETE /api/pantry without token
    let (s5, _) = send_request(&app, "DELETE", "/api/pantry", None, None).await;
    assert_eq!(s5, StatusCode::UNAUTHORIZED);

    // Invalid / forged token
    let (s6, _) = send_request(
        &app,
        "GET",
        "/api/pantry",
        Some("invalid.jwt.token"),
        None,
    )
    .await;
    assert_eq!(s6, StatusCode::UNAUTHORIZED);
}

// ----------------------------------------------------------------------------
// 11. INTEGRATION FLOW: PANTRY -> SEARCH-BY-INGREDIENTS & SUGGEST
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_11_integration_pantry_to_search_by_ingredients() {
    let (app, pool) = setup_test_app().await;
    let (_uid, token) = create_test_user(&pool, "chef_flow", "flow@bepviet.vn").await;

    // 1. User adds ingredients that match canonical seeded recipes (e.g. Canh bí đao sườn non: Sườn non, Bí đao)
    send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token),
        Some(json!({
            "names": ["sườn non", "bí đao", "hành tím"]
        })),
    )
    .await;

    // 2. Fetch pantry to get ingredientNames
    let (status_pantry, body_pantry) = send_request(&app, "GET", "/api/pantry", Some(&token), None).await;
    assert_eq!(status_pantry, StatusCode::OK);

    let ingredient_names = body_pantry["ingredientNames"].as_array().unwrap();
    let query_param = ingredient_names
        .iter()
        .map(|v| v.as_str().unwrap())
        .collect::<Vec<_>>()
        .join(",");

    // 3. Query /api/Recipes/search-by-ingredients with the pantry ingredients
    let (status_search, body_search) = send_request(
        &app,
        "GET",
        &format!("/api/Recipes/search-by-ingredients?ingredients={}", query_param),
        Some(&token),
        None,
    )
    .await;

    assert_eq!(status_search, StatusCode::OK);
    let recipes = body_search.as_array().expect("Expected recipes array");
    assert!(!recipes.is_empty(), "Should return matching recipes for sườn non & bí đao");

    // The top recipe should have high matchScore
    let top_recipe = &recipes[0];
    assert!(top_recipe["matchScore"].as_f64().unwrap() > 0.0);
    assert!(!top_recipe["matchedIngredients"].as_array().unwrap().is_empty());

    // 4. Test direct pantry suggest endpoint: GET /api/pantry/suggest
    let (status_sug, body_sug) = send_request(&app, "GET", "/api/pantry/suggest", Some(&token), None).await;
    assert_eq!(status_sug, StatusCode::OK);
    let sug_recipes = body_sug.as_array().unwrap();
    assert!(!sug_recipes.is_empty());
}

// ----------------------------------------------------------------------------
// 12. DUAL ROUTE VERIFICATION: /api/kitchen-bag WORKS IDENTICALLY TO /api/pantry
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_12_dual_route_kitchen_bag_parity() {
    let (app, pool) = setup_test_app().await;
    let (_uid, token) = create_test_user(&pool, "chef_bag", "bag@bepviet.vn").await;

    // POST /api/kitchen-bag
    let (s_post, b_post) = send_request(
        &app,
        "POST",
        "/api/kitchen-bag",
        Some(&token),
        Some(json!({ "name": "cải thìa", "amount": 200.0, "unit": "g" })),
    )
    .await;
    assert!(s_post == StatusCode::CREATED || s_post == StatusCode::OK);
    let item_id = b_post["item"]["id"].as_i64().unwrap();

    // GET /api/kitchen-bag
    let (s_get, b_get) = send_request(&app, "GET", "/api/kitchen-bag", Some(&token), None).await;
    assert_eq!(s_get, StatusCode::OK);
    assert_eq!(b_get["items"][0]["name"], "cải thìa");

    // PUT /api/kitchen-bag/:id
    let (s_put, b_put) = send_request(
        &app,
        "PUT",
        &format!("/api/kitchen-bag/{}", item_id),
        Some(&token),
        Some(json!({ "amount": 350.0 })),
    )
    .await;
    assert_eq!(s_put, StatusCode::OK);
    assert_eq!(b_put["item"]["amount"], 350.0);

    // DELETE /api/kitchen-bag/:id
    let (s_del, _) = send_request(
        &app,
        "DELETE",
        &format!("/api/kitchen-bag/{}", item_id),
        Some(&token),
        None,
    )
    .await;
    assert_eq!(s_del, StatusCode::OK);

    // Verify empty via /api/pantry
    let (_, b_pantry) = send_request(&app, "GET", "/api/pantry", Some(&token), None).await;
    assert_eq!(b_pantry["items"].as_array().unwrap().len(), 0);
}

// ----------------------------------------------------------------------------
// 13. EDGE CASES: EMPTY NAME REJECTION & ACCUMULATING DUPLICATES
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_13_edge_cases_and_duplicate_handling() {
    let (app, pool) = setup_test_app().await;
    let (_uid, token) = create_test_user(&pool, "chef_edge", "edge@bepviet.vn").await;

    // 1. Empty name rejection
    let (s_empty, _) = send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token),
        Some(json!({ "name": "   " })),
    )
    .await;
    assert_eq!(s_empty, StatusCode::BAD_REQUEST);

    // 2. Add item once
    let (s_add1, b_add1) = send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token),
        Some(json!({ "name": "  Thịt Bò  ", "amount": 200.0, "unit": "g" })),
    )
    .await;
    assert!(s_add1 == StatusCode::CREATED || s_add1 == StatusCode::OK);
    let item_id = b_add1["item"]["id"].as_i64().unwrap();

    // 3. Add same item again with mixed casing & whitespace -> amount should accumulate
    let (s_add2, b_add2) = send_request(
        &app,
        "POST",
        "/api/pantry",
        Some(&token),
        Some(json!({ "name": "thịt bò", "amount": 300.0, "unit": "g" })),
    )
    .await;
    assert!(s_add2 == StatusCode::CREATED || s_add2 == StatusCode::OK);
    assert_eq!(b_add2["item"]["id"], item_id);
    assert_eq!(b_add2["item"]["amount"], 500.0); // 200 + 300

    // Verify GET only has 1 deduplicated item
    let (_, b_get) = send_request(&app, "GET", "/api/pantry", Some(&token), None).await;
    assert_eq!(b_get["items"].as_array().unwrap().len(), 1);
    assert_eq!(b_get["items"][0]["amount"], 500.0);
}

// ----------------------------------------------------------------------------
// 14. FOREIGN KEY CASCADE: USER DELETION CASCADES PANTRY ITEMS
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_14_user_deletion_cascades_pantry_items() {
    let (_app, pool) = setup_test_app().await;
    let (uid, _token) = create_test_user(&pool, "user_to_delete", "delete_me@bepviet.vn").await;

    // Add pantry items directly to db
    let now = chrono::Utc::now().to_rfc3339();
    sqlx::query("INSERT INTO pantry_items (user_id, name, amount, unit, created_at, updated_at) VALUES (?, 'trứng', 10.0, 'quả', ?, ?)")
        .bind(uid)
        .bind(&now)
        .bind(&now)
        .execute(&pool)
        .await
        .unwrap();

    let count_before: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(uid)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count_before.0, 1);

    // Delete user
    sqlx::query("DELETE FROM users WHERE id = ?")
        .bind(uid)
        .execute(&pool)
        .await
        .unwrap();

    // Verify pantry items were cascade deleted
    let count_after: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(uid)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count_after.0, 0);
}

// ----------------------------------------------------------------------------
// 15. ADVERSARIAL: SQL INJECTION RESILIENCE IN PANTRY INPUTS
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_15_adversarial_sqli_resilience() {
    let (app, pool) = setup_test_app().await;
    let (uid, token) = create_test_user(&pool, "sqli_user", "sqli@bepviet.vn").await;

    let malicious_names = vec![
        "thịt'; DROP TABLE pantry_items; --",
        "cà chua' OR '1'='1",
        "\" UNION SELECT * FROM users --",
    ];

    for mal_name in &malicious_names {
        let (s, b) = send_request(
            &app,
            "POST",
            "/api/pantry",
            Some(&token),
            Some(json!({ "name": mal_name, "amount": 100.0 })),
        )
        .await;

        assert!(s == StatusCode::CREATED || s == StatusCode::OK);
        assert_eq!(b["item"]["name"], mal_name.to_lowercase());
    }

    // Verify table still intact and rows safely inserted
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(uid)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 3);

    // SQLi in ?name= query param
    let (del_status, _) = send_request(
        &app,
        "DELETE",
        "/api/pantry?name=something'%20OR%20'1'='1",
        Some(&token),
        None,
    )
    .await;
    // Should be 404 because no item literally has that name
    assert_eq!(del_status, StatusCode::NOT_FOUND);

    // Rows still intact
    let count2: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(uid)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count2.0, 3);
}

// ----------------------------------------------------------------------------
// 16. CONCURRENCY HAMMER: 20 CONCURRENT TASKS ADDING TO USER'S PANTRY
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_16_concurrency_hammer_distinct_and_duplicate_additions() {
    let (app, pool) = setup_test_app().await;
    let (uid, token) = create_test_user(&pool, "hammer_user", "hammer@bepviet.vn").await;

    let mut handles = vec![];
    for i in 0..20 {
        let app_clone = app.clone();
        let tok_clone = token.clone();
        handles.push(tokio::spawn(async move {
            let item_name = format!("nguyên liệu {}", i % 5); // 5 distinct items with 4 additions each
            send_request(
                &app_clone,
                "POST",
                "/api/pantry",
                Some(&tok_clone),
                Some(json!({ "name": item_name, "amount": 10.0 })),
            )
            .await
        }));
    }

    for h in handles {
        let (status, _) = h.await.unwrap();
        assert!(status == StatusCode::CREATED || status == StatusCode::OK);
    }

    // Verify 5 distinct deduplicated items exist
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM pantry_items WHERE user_id = ?")
        .bind(uid)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count.0, 5);

    // Verify total amount across the 5 items is 20 * 10 = 200.0
    let total_amount: (f64,) = sqlx::query_as("SELECT SUM(amount) FROM pantry_items WHERE user_id = ?")
        .bind(uid)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!((total_amount.0 - 200.0).abs() < 1e-4);
}

// ----------------------------------------------------------------------------
// 17. ROUTE ALIASES MATRIX: /api/Pantry, /api/KitchenBag, /api/kitchenbag
// ----------------------------------------------------------------------------
#[tokio::test]
async fn test_17_route_aliases_matrix() {
    let (app, pool) = setup_test_app().await;
    let (_uid, token) = create_test_user(&pool, "alias_user", "alias@bepviet.vn").await;

    let alias_routes = [
        "/api/pantry",
        "/api/Pantry",
        "/api/kitchen-bag",
        "/api/KitchenBag",
        "/api/kitchenbag",
    ];

    for (idx, route) in alias_routes.iter().enumerate() {
        let name = format!("gia vị {}", idx);
        let (s_post, b_post) = send_request(
            &app,
            "POST",
            route,
            Some(&token),
            Some(json!({ "name": name })),
        )
        .await;
        assert!(s_post == StatusCode::CREATED || s_post == StatusCode::OK);
        assert_eq!(b_post["item"]["name"], name);

        let (s_get, b_get) = send_request(&app, "GET", route, Some(&token), None).await;
        assert_eq!(s_get, StatusCode::OK);
        assert!(b_get["items"].as_array().unwrap().len() > idx);
    }
}

