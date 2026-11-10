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
async fn test_01_user_registration_success() {
    let (app, _pool) = setup_test_app().await;

    // 1. Explicit username and displayName
    let payload = json!({
        "email": "tester1@example.com",
        "password": "SecurePassword123!",
        "username": "tester1",
        "displayName": "Tester One"
    });

    let (status, body) = send_request(&app, "POST", "/api/Account/register", None, Some(payload)).await;
    assert!(
        status == StatusCode::OK || status == StatusCode::CREATED,
        "Expected 200 or 201, got {}",
        status
    );
    assert!(body["token"].is_string());
    assert!(body["userId"].as_i64().unwrap() > 0);
    assert_eq!(body["email"], "tester1@example.com");
    assert_eq!(body["username"], "tester1");
    assert_eq!(body["displayName"], "Tester One");
    assert_eq!(body["role"], "User");

    // 2. Auto-generated username when username is omitted (using /api/auth/register alias)
    let payload_auto = json!({
        "email": "auto_generated@example.com",
        "password": "SecurePassword123!"
    });

    let (status_auto, body_auto) =
        send_request(&app, "POST", "/api/auth/register", None, Some(payload_auto)).await;
    assert!(status_auto == StatusCode::OK || status_auto == StatusCode::CREATED);
    assert!(body_auto["token"].is_string());
    let auto_username = body_auto["username"].as_str().unwrap();
    assert!(
        auto_username.starts_with("auto_generated_"),
        "Username was not auto-generated properly: {}",
        auto_username
    );
}

#[tokio::test]
async fn test_02_duplicate_email_rejection() {
    let (app, _pool) = setup_test_app().await;

    let payload = json!({
        "email": "duplicate@example.com",
        "password": "SecurePassword123!",
        "username": "dupuser1"
    });

    let (status, _) = send_request(&app, "POST", "/api/Account/register", None, Some(payload)).await;
    assert!(status == StatusCode::OK || status == StatusCode::CREATED);

    // Try registering the same email again with a different username
    let duplicate_payload = json!({
        "email": "duplicate@example.com",
        "password": "SecurePassword123!",
        "username": "dupuser2"
    });

    let (dup_status, dup_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(duplicate_payload)).await;
    assert_eq!(dup_status, StatusCode::BAD_REQUEST);
    assert!(
        dup_body["message"].as_str().unwrap().contains("Email đã được sử dụng"),
        "Unexpected error message: {:?}",
        dup_body
    );
}

#[tokio::test]
async fn test_03_weak_password_rejection() {
    let (app, _pool) = setup_test_app().await;

    let weak_passwords = vec![
        "Short1!",       // < 8 chars
        "NoDigitsHere!", // missing digit
        "lowercase123!", // missing uppercase
        "UPPERCASE123!", // missing lowercase
        "NoSpecial123",  // missing special character
    ];

    for (i, weak_pwd) in weak_passwords.into_iter().enumerate() {
        let payload = json!({
            "email": format!("weak_{}@example.com", i),
            "password": weak_pwd,
            "username": format!("weakuser_{}", i)
        });

        let (status, body) =
            send_request(&app, "POST", "/api/Account/register", None, Some(payload)).await;
        assert_eq!(
            status,
            StatusCode::BAD_REQUEST,
            "Password '{}' was unexpectedly accepted",
            weak_pwd
        );
        assert!(
            body["message"].as_str().unwrap().contains("Mật khẩu phải bao gồm"),
            "Expected complexity rejection message for '{}', got {:?}",
            weak_pwd,
            body
        );
    }
}

#[tokio::test]
async fn test_04_successful_login_with_username_and_email() {
    let (app, _pool) = setup_test_app().await;

    // Register user first
    let reg_payload = json!({
        "email": "loginuser@example.com",
        "password": "SecurePassword123!",
        "username": "loginuser",
        "displayName": "Login Test User"
    });
    let (reg_status, _) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    assert!(reg_status == StatusCode::OK || reg_status == StatusCode::CREATED);

    // 4a. Login with email
    let login_by_email = json!({
        "usernameOrEmail": "loginuser@example.com",
        "password": "SecurePassword123!"
    });
    let (status_email, body_email) =
        send_request(&app, "POST", "/api/Account/login", None, Some(login_by_email)).await;
    assert_eq!(status_email, StatusCode::OK);
    assert!(body_email["token"].is_string());
    assert_eq!(body_email["email"], "loginuser@example.com");
    assert_eq!(body_email["username"], "loginuser");

    // 4b. Login with username (using /api/auth/login alias)
    let login_by_username = json!({
        "usernameOrEmail": "loginuser",
        "password": "SecurePassword123!"
    });
    let (status_username, body_username) =
        send_request(&app, "POST", "/api/auth/login", None, Some(login_by_username)).await;
    assert_eq!(status_username, StatusCode::OK);
    assert!(body_username["token"].is_string());
    assert_eq!(body_username["username"], "loginuser");

    // 4c. Login with 'email' alias field and rememberMe = true
    let login_by_alias = json!({
        "email": "loginuser@example.com",
        "password": "SecurePassword123!",
        "rememberMe": true
    });
    let (status_alias, body_alias) =
        send_request(&app, "POST", "/api/account/login", None, Some(login_by_alias)).await;
    assert_eq!(status_alias, StatusCode::OK);
    assert!(body_alias["token"].is_string());
}

#[tokio::test]
async fn test_05_failed_login_with_wrong_password() {
    let (app, _pool) = setup_test_app().await;

    // Register user
    let reg_payload = json!({
        "email": "wrongpass@example.com",
        "password": "SecurePassword123!",
        "username": "wrongpassuser"
    });
    let (reg_status, _) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    assert!(reg_status == StatusCode::OK || reg_status == StatusCode::CREATED);

    // Login with incorrect password
    let bad_login = json!({
        "usernameOrEmail": "wrongpass@example.com",
        "password": "TotallyWrongPassword999!"
    });
    let (status, body) =
        send_request(&app, "POST", "/api/Account/login", None, Some(bad_login)).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert!(body["message"]
        .as_str()
        .unwrap()
        .contains("Email/tên đăng nhập hoặc mật khẩu không chính xác"));

    // Login with non-existent user
    let non_existent = json!({
        "usernameOrEmail": "nonexistent@example.com",
        "password": "SecurePassword123!"
    });
    let (status_ne, _) =
        send_request(&app, "POST", "/api/Account/login", None, Some(non_existent)).await;
    assert_eq!(status_ne, StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn test_06_legacy_bcrypt_password_verification() {
    let (app, pool) = setup_test_app().await;

    // Generate BCrypt hash for legacy user
    let raw_password = "LegacyBcryptPassword123!";
    let bcrypt_hash = bcrypt::hash(raw_password, bcrypt::DEFAULT_COST).unwrap();
    assert!(
        bcrypt_hash.starts_with("$2b$") || bcrypt_hash.starts_with("$2a$"),
        "Expected bcrypt hash prefix, got {}",
        bcrypt_hash
    );

    let now = chrono::Utc::now().to_rfc3339();
    sqlx::query(
        "INSERT INTO users (username, email, password_hash, display_name, avatar_url, is_active, role, created_at, updated_at) \
         VALUES ('legacyuser', 'legacy@example.com', ?, 'Legacy User', NULL, 1, 'User', ?, ?)",
    )
    .bind(&bcrypt_hash)
    .bind(&now)
    .bind(&now)
    .execute(&pool)
    .await
    .unwrap();

    // 6a. Login with correct password must succeed via BCrypt fallback
    let login_payload = json!({
        "usernameOrEmail": "legacy@example.com",
        "password": raw_password
    });
    let (status, body) =
        send_request(&app, "POST", "/api/Account/login", None, Some(login_payload)).await;
    assert_eq!(status, StatusCode::OK);
    assert!(body["token"].is_string());
    assert_eq!(body["username"], "legacyuser");

    // 6b. Login with wrong password must fail
    let bad_payload = json!({
        "usernameOrEmail": "legacy@example.com",
        "password": "WrongPasswordLegacy123!"
    });
    let (bad_status, _) =
        send_request(&app, "POST", "/api/Account/login", None, Some(bad_payload)).await;
    assert_eq!(bad_status, StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn test_07_accessing_protected_profile_without_token() {
    let (app, _pool) = setup_test_app().await;

    // 1. Completely missing token
    let (status_no_token, body_no_token) =
        send_request(&app, "GET", "/api/Account/profile", None, None).await;
    assert_eq!(status_no_token, StatusCode::UNAUTHORIZED);
    assert_eq!(
        body_no_token["message"],
        "Vui lòng đăng nhập để tiếp tục."
    );
    assert_eq!(body_no_token["error"], "Unauthorized");

    // 2. Malformed token
    let (status_invalid, body_invalid) = send_request(
        &app,
        "GET",
        "/api/Account/profile",
        Some("invalid.token.here"),
        None,
    )
    .await;
    assert_eq!(status_invalid, StatusCode::UNAUTHORIZED);
    assert_eq!(body_invalid["error"], "Unauthorized");
}

#[tokio::test]
async fn test_08_accessing_protected_profile_with_valid_token() {
    let (app, _pool) = setup_test_app().await;

    let reg_payload = json!({
        "email": "profileuser@example.com",
        "password": "SecurePassword123!",
        "username": "profileuser",
        "displayName": "Profile Viewer"
    });
    let (_, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    let token = reg_body["token"].as_str().unwrap();

    // GET /api/Account/profile
    let (status, profile_body) =
        send_request(&app, "GET", "/api/Account/profile", Some(token), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(profile_body["email"], "profileuser@example.com");
    assert_eq!(profile_body["username"], "profileuser");
    assert_eq!(profile_body["displayName"], "Profile Viewer");
    assert_eq!(profile_body["name"], "Profile Viewer");
    assert_eq!(profile_body["role"], "User");
    assert_eq!(profile_body["isActive"], true);
    assert!(profile_body["userId"].as_i64().unwrap() > 0);
    assert_eq!(profile_body["userId"], profile_body["id"]);

    // Alias GET /api/auth/profile
    let (status_alias, profile_alias) =
        send_request(&app, "GET", "/api/auth/profile", Some(token), None).await;
    assert_eq!(status_alias, StatusCode::OK);
    assert_eq!(profile_alias["username"], "profileuser");
}

#[tokio::test]
async fn test_09_updating_profile() {
    let (app, _pool) = setup_test_app().await;

    let reg_payload = json!({
        "email": "updateuser@example.com",
        "password": "SecurePassword123!",
        "username": "updateuser",
        "displayName": "Initial Name"
    });
    let (_, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    let token = reg_body["token"].as_str().unwrap();

    // Update display name and avatar url
    let update_payload = json!({
        "displayName": "Chef Update",
        "avatarUrl": "https://example.com/chef.jpg"
    });
    let (status_put, put_body) = send_request(
        &app,
        "PUT",
        "/api/Account/update-profile",
        Some(token),
        Some(update_payload),
    )
    .await;
    assert_eq!(status_put, StatusCode::OK);
    assert_eq!(put_body["success"], true);

    // Verify updated profile
    let (status_get, get_body) =
        send_request(&app, "GET", "/api/Account/profile", Some(token), None).await;
    assert_eq!(status_get, StatusCode::OK);
    assert_eq!(get_body["displayName"], "Chef Update");
    assert_eq!(get_body["name"], "Chef Update");
    assert_eq!(get_body["avatarUrl"], "https://example.com/chef.jpg");
}

#[tokio::test]
async fn test_10_changing_password_and_login_verification() {
    let (app, _pool) = setup_test_app().await;

    let reg_payload = json!({
        "email": "changepwd@example.com",
        "password": "OldPassword123!",
        "username": "changepwduser"
    });
    let (_, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    let token = reg_body["token"].as_str().unwrap();

    // 10a. Fail with wrong current password
    let bad_change = json!({
        "currentPassword": "WrongCurrentPassword123!",
        "newPassword": "NewStrongPassword456@"
    });
    let (status_bad_curr, _) = send_request(
        &app,
        "POST",
        "/api/Account/change-password",
        Some(token),
        Some(bad_change),
    )
    .await;
    assert_eq!(status_bad_curr, StatusCode::BAD_REQUEST);

    // 10b. Fail with weak new password
    let weak_change = json!({
        "currentPassword": "OldPassword123!",
        "newPassword": "weak"
    });
    let (status_weak, _) = send_request(
        &app,
        "POST",
        "/api/Account/change-password",
        Some(token),
        Some(weak_change),
    )
    .await;
    assert_eq!(status_weak, StatusCode::BAD_REQUEST);

    // 10c. Successful password change
    let valid_change = json!({
        "currentPassword": "OldPassword123!",
        "newPassword": "NewStrongPassword456@"
    });
    let (status_ok, body_ok) = send_request(
        &app,
        "POST",
        "/api/Account/change-password",
        Some(token),
        Some(valid_change),
    )
    .await;
    assert_eq!(status_ok, StatusCode::OK);
    assert_eq!(body_ok["success"], true);

    // 10d. Login with old password fails
    let old_login = json!({
        "usernameOrEmail": "changepwd@example.com",
        "password": "OldPassword123!"
    });
    let (status_old_login, _) =
        send_request(&app, "POST", "/api/Account/login", None, Some(old_login)).await;
    assert_eq!(status_old_login, StatusCode::UNAUTHORIZED);

    // 10e. Login with new password succeeds
    let new_login = json!({
        "usernameOrEmail": "changepwd@example.com",
        "password": "NewStrongPassword456@"
    });
    let (status_new_login, body_new_login) =
        send_request(&app, "POST", "/api/Account/login", None, Some(new_login)).await;
    assert_eq!(status_new_login, StatusCode::OK);
    assert!(body_new_login["token"].is_string());
}

#[tokio::test]
async fn test_11_upgrading_to_vip() {
    let (app, _pool) = setup_test_app().await;

    let reg_payload = json!({
        "email": "vipuser@example.com",
        "password": "SecurePassword123!",
        "username": "vipuser"
    });
    let (_, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    let token = reg_body["token"].as_str().unwrap();

    // Call upgrade to VIP
    let (status_vip, body_vip) = send_request(
        &app,
        "POST",
        "/api/Account/upgrade-to-vip",
        Some(token),
        None,
    )
    .await;
    assert_eq!(status_vip, StatusCode::OK);
    assert_eq!(body_vip["role"], "VIP");

    // Verify role in profile
    let (status_prof, body_prof) =
        send_request(&app, "GET", "/api/Account/profile", Some(token), None).await;
    assert_eq!(status_prof, StatusCode::OK);
    assert_eq!(body_prof["role"], "VIP");
}

#[tokio::test]
async fn test_12_disabled_account_login_rejected() {
    let (app, pool) = setup_test_app().await;

    let reg_payload = json!({
        "email": "disabled@example.com",
        "password": "SecurePassword123!",
        "username": "disableduser"
    });
    let (_, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    let user_id = reg_body["userId"].as_i64().unwrap();

    // Disable the account in database
    sqlx::query("UPDATE users SET is_active = 0 WHERE id = ?")
        .bind(user_id)
        .execute(&pool)
        .await
        .unwrap();

    // Attempt login
    let login_payload = json!({
        "usernameOrEmail": "disabled@example.com",
        "password": "SecurePassword123!"
    });
    let (status, body) =
        send_request(&app, "POST", "/api/Account/login", None, Some(login_payload)).await;
    assert_eq!(status, StatusCode::FORBIDDEN);
    assert!(body["message"]
        .as_str()
        .unwrap()
        .contains("Tài khoản đã bị vô hiệu hóa"));
}
