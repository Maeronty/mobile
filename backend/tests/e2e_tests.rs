mod common;

use axum::{
    body::Body,
    http::{header, Request, StatusCode},
    Router,
};
use common::setup_test_app;
use http_body_util::BodyExt;
use serde_json::{json, Value};
use tower::ServiceExt;

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

#[tokio::test]
async fn test_full_user_mobile_e2e_journey() {
    let (app, _pool) = setup_test_app().await;

    // =========================================================================
    // STEP 1: Registration (R1)
    // =========================================================================
    let (status, reg_body) = send_request(
        &app,
        "POST",
        "/api/Account/register",
        None,
        Some(json!({
            "username": "chef_e2e",
            "email": "chef_e2e@example.com",
            "password": "Password123!",
            "displayName": "Đầu Bếp E2E"
        })),
    )
    .await;

    assert_eq!(status, StatusCode::OK, "Registration should succeed: {reg_body}");
    assert_eq!(reg_body["username"], "chef_e2e");
    assert_eq!(reg_body["email"], "chef_e2e@example.com");

    // =========================================================================
    // STEP 2: Login & JWT Issuance (R1)
    // =========================================================================
    let (status, login_body) = send_request(
        &app,
        "POST",
        "/api/Account/login",
        None,
        Some(json!({
            "username": "chef_e2e",
            "password": "Password123!"
        })),
    )
    .await;

    assert_eq!(status, StatusCode::OK, "Login should succeed: {login_body}");
    let token = login_body["token"]
        .as_str()
        .expect("JWT token must be present")
        .to_string();
    assert!(!token.is_empty(), "Token must not be empty");

    // =========================================================================
    // STEP 3: Get User Profile & Update Profile (R1)
    // =========================================================================
    let (status, profile_body) = send_request(
        &app,
        "GET",
        "/api/Account/profile",
        Some(&token),
        None,
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(profile_body["username"], "chef_e2e");

    let (status, _) = send_request(
        &app,
        "PUT",
        "/api/Account/update-profile",
        Some(&token),
        Some(json!({
            "displayName": "Master Chef E2E",
            "bio": "Chuyên gia ẩm thực Việt Nam"
        })),
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    // =========================================================================
    // STEP 4: Browse Catalog in Spoonacular Format (R2 - Flutter compatibility)
    // =========================================================================
    let (status, catalog_body) = send_request(
        &app,
        "GET",
        "/catalog",
        None,
        None,
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    let catalog_arr = catalog_body.as_array().expect("Catalog must be a JSON array");
    assert!(!catalog_arr.is_empty(), "Catalog should contain seeded recipes");

    let first_recipe = &catalog_arr[0];
    assert!(first_recipe["id"].is_number());
    assert!(first_recipe["title"].is_string());
    assert!(first_recipe["nutrients"].is_object());
    assert!(first_recipe["nutrients"]["Calories"].is_number());
    assert!(first_recipe["ingredients"].is_array());
    assert!(first_recipe["steps"].is_array());

    let sample_recipe_id = first_recipe["id"].as_i64().unwrap();

    // =========================================================================
    // STEP 5: View Recipe Detail (R2)
    // =========================================================================
    let (status, detail_body) = send_request(
        &app,
        "GET",
        &format!("/api/Recipes/{}", sample_recipe_id),
        Some(&token),
        None,
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(detail_body["recipeID"], sample_recipe_id);
    assert_eq!(detail_body["isFavorited"], false);

    // =========================================================================
    // STEP 6: Keyword Search (R2)
    // =========================================================================
    let (status, search_body) = send_request(
        &app,
        "GET",
        "/api/Recipes/search?term=gà",
        Some(&token),
        None,
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert!(search_body.is_array());

    // =========================================================================
    // STEP 7: Chức năng Tủ lạnh (Pantry) đã bị gỡ → route không còn tồn tại
    // =========================================================================
    let (status, _) = send_request(&app, "GET", "/api/pantry", Some(&token), None).await;
    assert_eq!(status, StatusCode::NOT_FOUND, "Pantry API đã bị gỡ");

    // =========================================================================
    // STEP 8: Favorites Management (R3)
    // =========================================================================
    // Toggle favorite -> true
    let (status, fav_toggle) = send_request(
        &app,
        "POST",
        &format!("/api/Recipes/{}/favorite", sample_recipe_id),
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(fav_toggle["isFavorited"], true);

    // Get user favorites
    let (status, fav_list) = send_request(
        &app,
        "GET",
        "/api/Recipes/favorites",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let fav_arr = fav_list.as_array().expect("Favorites list must be an array");
    assert_eq!(fav_arr.len(), 1);
    assert_eq!(fav_arr[0]["recipeID"], sample_recipe_id);
    assert_eq!(fav_arr[0]["isFavorited"], true);

    let id2 = catalog_arr[1]["id"].as_i64().expect("id2");
    let id3 = catalog_arr[2]["id"].as_i64().expect("id3");

    // Batch sync offline favorites
    let (status, sync_resp) = send_request(
        &app,
        "POST",
        "/api/Recipes/sync-favorites",
        Some(&token),
        Some(json!([id2, id3])),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "Batch sync should succeed: {sync_resp}");

    let (_, updated_fav_list) = send_request(
        &app,
        "GET",
        "/api/Recipes/favorites",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(updated_fav_list.as_array().unwrap().len(), 3);

    // Toggle favorite again -> false
    let (status, fav_untoggle) = send_request(
        &app,
        "POST",
        &format!("/api/Recipes/{}/favorite", sample_recipe_id),
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(fav_untoggle["isFavorited"], false);

    // =========================================================================
    // STEP 9: Change Password & Re-authenticate (R1 Security)
    // =========================================================================
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Account/change-password",
        Some(&token),
        Some(json!({
            "oldPassword": "Password123!",
            "newPassword": "NewPassword456!"
        })),
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    // Old password fails
    let (status, _) = send_request(
        &app,
        "POST",
        "/api/Account/login",
        None,
        Some(json!({
            "username": "chef_e2e",
            "password": "Password123!"
        })),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);

    // New password succeeds
    let (status, new_login) = send_request(
        &app,
        "POST",
        "/api/Account/login",
        None,
        Some(json!({
            "username": "chef_e2e",
            "password": "NewPassword456!"
        })),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert!(new_login["token"].is_string());
}
