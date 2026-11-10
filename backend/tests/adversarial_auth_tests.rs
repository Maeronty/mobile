mod common;

use axum::{
    body::Body,
    http::{header, Request, StatusCode},
    Router,
};
use common::setup_test_app;
use http_body_util::BodyExt;
use jsonwebtoken::{encode, EncodingKey, Header};
use serde_json::{json, Value};
use sqlx::Row;
use std::time::Instant;
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

// =========================================================================
// 1. Password Complexity Boundaries & DOS Resilience
// =========================================================================

#[tokio::test]
async fn test_adv_pwd_boundaries_and_classes() {
    let (app, _pool) = setup_test_app().await;

    // Boundary cases that MUST FAIL (HTTP 400):
    let failing_passwords = vec![
        ("", "Empty password"),
        ("Aa1!", "4 characters (too short)"),
        ("Aa1!xxx", "7 characters boundary (strictly < 8)"),
        ("aa1!xxxx", "8 characters boundary - missing uppercase"),
        ("AA1!XXXX", "8 characters boundary - missing lowercase"),
        ("Aaa!xxxx", "8 characters boundary - missing digit"),
        ("Aa11xxxx", "8 characters boundary - missing special char"),
        ("        ", "8 whitespace characters"),
        ("Abcdefgh", "8 letters only (no digit, no special)"),
        ("12345678", "8 digits only"),
        ("!@#$%^&*", "8 special characters only"),
    ];

    for (pwd, desc) in failing_passwords {
        let payload = json!({
            "email": format!("test_boundary_{}@example.com", uuid::Uuid::new_v4().simple()),
            "password": pwd,
            "username": format!("user_{}", uuid::Uuid::new_v4().simple())
        });

        let (status, body) =
            send_request(&app, "POST", "/api/Account/register", None, Some(payload)).await;
        assert_eq!(
            status,
            StatusCode::BAD_REQUEST,
            "Password '{}' ({}) was unexpectedly accepted! Response: {:?}",
            pwd,
            desc,
            body
        );
        let msg = body["message"].as_str().unwrap_or("");
        assert!(
            msg.contains("Mật khẩu phải bao gồm"),
            "Expected password complexity message for ({}), got: {}",
            desc,
            msg
        );
    }

    // Boundary cases that MUST PASS (HTTP 200 or 201):
    let passing_passwords = vec![
        ("Aa1!xxxx", "Exact 8 chars with all 4 classes"),
        ("Zz9#aaaa", "Exact 8 chars with different classes"),
        ("1aA!bcde", "Exact 8 chars starting with digit"),
        ("!1aAbcde", "Exact 8 chars starting with special"),
        ("Aa1 xxxx", "Exact 8 chars with space as special character"),
        ("P@ssw0rd!", "9 chars standard compliant"),
    ];

    for (pwd, desc) in passing_passwords {
        let email = format!("pass_{}@example.com", uuid::Uuid::new_v4().simple());
        let username = format!("pass_{}", uuid::Uuid::new_v4().simple());
        let payload = json!({
            "email": email,
            "password": pwd,
            "username": username
        });

        let (status, body) =
            send_request(&app, "POST", "/api/Account/register", None, Some(payload)).await;
        assert!(
            status == StatusCode::OK || status == StatusCode::CREATED,
            "Password '{}' ({}) failed validation: status={}, body={:?}",
            pwd,
            desc,
            status,
            body
        );
        assert!(body["token"].is_string(), "Token must be returned");
    }
}

#[tokio::test]
async fn test_adv_pwd_1000_chars_dos_resilience() {
    let (app, _pool) = setup_test_app().await;

    // Generate a 1000-character valid password
    let long_filler = "x".repeat(996);
    let pwd_1000 = format!("Aa1!{}", long_filler);
    assert_eq!(pwd_1000.chars().count(), 1000);

    let email = "longpwd_user@example.com";
    let username = "longpwd_user";

    // 1. Registration with 1000-character password
    let start_reg = Instant::now();
    let reg_payload = json!({
        "email": email,
        "password": pwd_1000,
        "username": username,
        "displayName": "Long Pwd User"
    });

    let (reg_status, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    let reg_duration = start_reg.elapsed();

    assert!(
        reg_status == StatusCode::OK || reg_status == StatusCode::CREATED,
        "Registration with 1000-char password failed: status={}, body={:?}",
        reg_status,
        reg_body
    );
    assert!(
        reg_duration.as_secs_f64() < 5.0,
        "Registration with 1000-char password took too long: {:?}",
        reg_duration
    );
    let original_token = reg_body["token"].as_str().unwrap();

    // 2. Successful Login with 1000-character password
    let start_login = Instant::now();
    let login_payload = json!({
        "usernameOrEmail": email,
        "password": pwd_1000
    });
    let (login_status, login_body) =
        send_request(&app, "POST", "/api/Account/login", None, Some(login_payload)).await;
    let login_duration = start_login.elapsed();

    assert_eq!(
        login_status,
        StatusCode::OK,
        "Login with 1000-char password failed: {:?}",
        login_body
    );
    assert!(
        login_duration.as_secs_f64() < 5.0,
        "Login verification with 1000-char password took too long: {:?}",
        login_duration
    );

    // 3. Failed Login with slightly modified 1000-character password
    let mut bad_1000 = pwd_1000.clone();
    bad_1000.replace_range(999..1000, "z");
    let bad_login_payload = json!({
        "usernameOrEmail": email,
        "password": bad_1000
    });
    let (bad_login_status, _) =
        send_request(&app, "POST", "/api/Account/login", None, Some(bad_login_payload)).await;
    assert_eq!(
        bad_login_status,
        StatusCode::UNAUTHORIZED,
        "Modified 1000-char password should have failed"
    );

    // 4. Change password to another 1000-character password
    let new_pwd_1000 = format!("Bb2@{}", "y".repeat(996));
    assert_eq!(new_pwd_1000.chars().count(), 1000);

    let change_payload = json!({
        "currentPassword": pwd_1000,
        "newPassword": new_pwd_1000
    });
    let (change_status, change_body) = send_request(
        &app,
        "POST",
        "/api/Account/change-password",
        Some(original_token),
        Some(change_payload),
    )
    .await;
    assert_eq!(
        change_status,
        StatusCode::OK,
        "Change password to 1000-char password failed: {:?}",
        change_body
    );

    // 5. Verify new 1000-char password works for login
    let new_login_payload = json!({
        "usernameOrEmail": username,
        "password": new_pwd_1000
    });
    let (new_login_status, _) =
        send_request(&app, "POST", "/api/Account/login", None, Some(new_login_payload)).await;
    assert_eq!(new_login_status, StatusCode::OK);
}

// =========================================================================
// 2. SQL Injection Resistance
// =========================================================================

#[tokio::test]
async fn test_adv_sql_injection_on_login_bypasses() {
    let (app, pool) = setup_test_app().await;

    // Seed a known legitimate user
    let legit_reg = json!({
        "email": "victim_admin@example.com",
        "password": "SecurePassword123!",
        "username": "victim_admin",
        "displayName": "Legitimate Admin"
    });
    let (reg_status, _) =
        send_request(&app, "POST", "/api/Account/register", None, Some(legit_reg)).await;
    assert!(reg_status == StatusCode::OK || reg_status == StatusCode::CREATED);

    let initial_user_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users")
        .fetch_one(&pool)
        .await
        .unwrap();

    // Adversarial SQL injection strings attempting authentication bypass or table destruction
    let malicious_identifiers = vec![
        "' OR '1'='1",
        "' OR '1'='1' --",
        "' OR 1=1 --",
        "' OR 'a'='a",
        "admin'--",
        "admin' /*",
        "victim_admin' --",
        "victim_admin' /*",
        "'; DROP TABLE users; --",
        "'; DELETE FROM users WHERE 1=1; --",
        "' UNION SELECT 1, 'admin', 'admin@evil.com', 'hacked', 'Hacked', NULL, 1, 'Admin', '', '' --",
        "1' UNION SELECT id, username, email, password_hash, display_name, avatar_url, is_active, role, created_at, updated_at FROM users --",
        "\" OR \"\"=\"",
        "admin' OR 1=1#",
    ];

    for injection in malicious_identifiers {
        let payload = json!({
            "usernameOrEmail": injection,
            "password": "ArbitraryPassword123!"
        });

        let (status, body) =
            send_request(&app, "POST", "/api/Account/login", None, Some(payload)).await;

        assert_eq!(
            status,
            StatusCode::UNAUTHORIZED,
            "SQL injection '{}' bypassed authentication or caused unexpected status! Response: {:?}",
            injection,
            body
        );
        assert!(
            body["token"].is_null(),
            "SQL injection '{}' must not issue a JWT token!",
            injection
        );
    }

    // Verify SQL injection in password field
    let malicious_passwords = vec![
        "' OR '1'='1",
        "'; DROP TABLE users; --",
        "' OR 1=1 --",
        "\" OR \"\"=\"",
    ];

    for injection_pwd in malicious_passwords {
        let payload = json!({
            "usernameOrEmail": "victim_admin",
            "password": injection_pwd
        });

        let (status, _) =
            send_request(&app, "POST", "/api/Account/login", None, Some(payload)).await;
        assert_eq!(
            status,
            StatusCode::UNAUTHORIZED,
            "Password injection '{}' bypassed authentication!",
            injection_pwd
        );
    }

    // Critical check: Ensure users table was NOT dropped or deleted
    let post_user_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users")
        .fetch_one(&pool)
        .await
        .expect("Users table should still exist and be queryable");
    assert_eq!(
        post_user_count, initial_user_count,
        "User count changed after SQL injection attempts!"
    );

    // Ensure legitimate user can still log in successfully
    let legit_login = json!({
        "usernameOrEmail": "victim_admin@example.com",
        "password": "SecurePassword123!"
    });
    let (legit_status, legit_body) =
        send_request(&app, "POST", "/api/Account/login", None, Some(legit_login)).await;
    assert_eq!(legit_status, StatusCode::OK);
    assert_eq!(legit_body["username"], "victim_admin");
}

#[tokio::test]
async fn test_adv_sql_injection_on_registration_and_persistence() {
    let (app, pool) = setup_test_app().await;

    // Test SQL injection in registration fields (displayName, username)
    let injection_username = "hacker'; DROP TABLE users; --";
    let injection_display = "Robert'); DROP TABLE recipes; --";
    let injection_avatar = "https://example.com/avatar.png'; DROP TABLE users; --";

    let reg_payload = json!({
        "email": "injection_test@example.com",
        "password": "SecurePassword123!",
        "username": injection_username,
        "displayName": injection_display
    });

    let (status, body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;

    assert!(
        status == StatusCode::OK || status == StatusCode::CREATED,
        "Registration with special SQL characters failed: status={}, body={:?}",
        status,
        body
    );

    let token = body["token"].as_str().unwrap();

    // Verify stored data: string must be preserved verbatim, without SQL execution
    let (prof_status, prof_body) =
        send_request(&app, "GET", "/api/Account/profile", Some(token), None).await;
    assert_eq!(prof_status, StatusCode::OK);
    assert_eq!(prof_body["username"], injection_username);
    assert_eq!(prof_body["displayName"], injection_display);

    // Verify recipes and users tables still exist and are functional
    let recipes_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM recipes")
        .fetch_one(&pool)
        .await
        .expect("Recipes table was damaged by injection in registration!");
    assert!(recipes_count >= 0);

    // Test SQL injection in update profile
    let update_payload = json!({
        "displayName": "Attacker' OR 1=1; --",
        "avatarUrl": injection_avatar
    });
    let (up_status, _) = send_request(
        &app,
        "PUT",
        "/api/Account/update-profile",
        Some(token),
        Some(update_payload),
    )
    .await;
    assert_eq!(up_status, StatusCode::OK);

    // Verify verbatim storage
    let (_, updated_prof) =
        send_request(&app, "GET", "/api/Account/profile", Some(token), None).await;
    assert_eq!(updated_prof["displayName"], "Attacker' OR 1=1; --");
    assert_eq!(updated_prof["avatarUrl"], injection_avatar);

    // Attempt login with the injection username
    let login_payload = json!({
        "usernameOrEmail": injection_username,
        "password": "SecurePassword123!"
    });
    let (login_status, login_body) =
        send_request(&app, "POST", "/api/Account/login", None, Some(login_payload)).await;
    assert_eq!(
        login_status,
        StatusCode::OK,
        "Failed to login with verbatim injection username"
    );
    assert_eq!(login_body["username"], injection_username);
}

// =========================================================================
// 3. Profile State Transitions & Edge Cases
// =========================================================================

#[tokio::test]
async fn test_adv_profile_update_empty_and_null_edge_cases() {
    let (app, _pool) = setup_test_app().await;

    // Register user with initial values
    let reg_payload = json!({
        "email": "edge_profile@example.com",
        "password": "SecurePassword123!",
        "username": "edge_profile_user",
        "displayName": "Initial Display"
    });
    let (_, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    let token = reg_body["token"].as_str().unwrap();

    // Set an initial avatarUrl
    let setup_avatar = json!({
        "avatarUrl": "https://example.com/initial_avatar.png"
    });
    let (setup_status, _) = send_request(
        &app,
        "PUT",
        "/api/Account/update-profile",
        Some(token),
        Some(setup_avatar),
    )
    .await;
    assert_eq!(setup_status, StatusCode::OK);

    // Verify both are set
    let (_, prof1) = send_request(&app, "GET", "/api/Account/profile", Some(token), None).await;
    assert_eq!(prof1["displayName"], "Initial Display");
    assert_eq!(prof1["avatarUrl"], "https://example.com/initial_avatar.png");

    // Edge Case 1: Empty JSON object `{}` -> Neither field is updated, both preserved
    let (empty_status, empty_body) =
        send_request(&app, "PUT", "/api/Account/update-profile", Some(token), Some(json!({}))).await;
    assert_eq!(empty_status, StatusCode::OK);
    assert_eq!(empty_body["success"], true);

    let (_, prof2) = send_request(&app, "GET", "/api/Account/profile", Some(token), None).await;
    assert_eq!(prof2["displayName"], "Initial Display", "displayName was corrupted by empty payload");
    assert_eq!(
        prof2["avatarUrl"], "https://example.com/initial_avatar.png",
        "avatarUrl was corrupted by empty payload"
    );

    // Edge Case 2: Explicit null fields `{"displayName": null, "avatarUrl": null}`
    let null_payload = json!({
        "displayName": null,
        "avatarUrl": null
    });
    let (null_status, _) = send_request(
        &app,
        "PUT",
        "/api/Account/update-profile",
        Some(token),
        Some(null_payload),
    )
    .await;
    assert_eq!(null_status, StatusCode::OK);

    let (_, prof3) = send_request(&app, "GET", "/api/Account/profile", Some(token), None).await;
    assert_eq!(prof3["displayName"], "Initial Display");
    assert_eq!(prof3["avatarUrl"], "https://example.com/initial_avatar.png");

    // Edge Case 3: Partial update - update ONLY displayName, avatarUrl MUST remain intact
    let partial_dn = json!({
        "displayName": "Brand New Name"
    });
    let (part_status, _) = send_request(
        &app,
        "PUT",
        "/api/Account/update-profile",
        Some(token),
        Some(partial_dn),
    )
    .await;
    assert_eq!(part_status, StatusCode::OK);

    let (_, prof4) = send_request(&app, "GET", "/api/Account/profile", Some(token), None).await;
    assert_eq!(prof4["displayName"], "Brand New Name");
    assert_eq!(prof4["avatarUrl"], "https://example.com/initial_avatar.png");

    // Edge Case 4: Partial update - update ONLY avatarUrl, displayName MUST remain intact
    let partial_av = json!({
        "avatarUrl": "https://example.com/second_avatar.png"
    });
    let (part_av_status, _) = send_request(
        &app,
        "PUT",
        "/api/Account/update-profile",
        Some(token),
        Some(partial_av),
    )
    .await;
    assert_eq!(part_av_status, StatusCode::OK);

    let (_, prof5) = send_request(&app, "GET", "/api/Account/profile", Some(token), None).await;
    assert_eq!(prof5["displayName"], "Brand New Name");
    assert_eq!(prof5["avatarUrl"], "https://example.com/second_avatar.png");

    // Edge Case 5: Client uses alias 'name' instead of 'displayName'
    let alias_dn = json!({
        "name": "Alias Updated Name"
    });
    let (alias_status, _) = send_request(
        &app,
        "PUT",
        "/api/Account/update-profile",
        Some(token),
        Some(alias_dn),
    )
    .await;
    assert_eq!(alias_status, StatusCode::OK);

    let (_, prof6) = send_request(&app, "GET", "/api/Account/profile", Some(token), None).await;
    assert_eq!(prof6["displayName"], "Alias Updated Name");
    assert_eq!(prof6["name"], "Alias Updated Name");
}

#[tokio::test]
async fn test_adv_password_change_edge_cases() {
    let (app, pool) = setup_test_app().await;

    let reg_payload = json!({
        "email": "pw_edge@example.com",
        "password": "InitialPassword123!",
        "username": "pw_edge_user"
    });
    let (_, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    let token = reg_body["token"].as_str().unwrap();

    // 1. Wrong current password -> 400 Bad Request
    let wrong_curr = json!({
        "currentPassword": "WrongInitialPassword999!",
        "newPassword": "ValidNewPassword456@"
    });
    let (status_wc, body_wc) = send_request(
        &app,
        "POST",
        "/api/Account/change-password",
        Some(token),
        Some(wrong_curr),
    )
    .await;
    assert_eq!(status_wc, StatusCode::BAD_REQUEST);
    assert!(body_wc["message"]
        .as_str()
        .unwrap()
        .contains("Mật khẩu hiện tại không đúng"));

    // 2. Weak new password (boundary 7 chars) -> 400 Bad Request
    let weak_new_1 = json!({
        "currentPassword": "InitialPassword123!",
        "newPassword": "Aa1!xxx"
    });
    let (status_wn1, body_wn1) = send_request(
        &app,
        "POST",
        "/api/Account/change-password",
        Some(token),
        Some(weak_new_1),
    )
    .await;
    assert_eq!(status_wn1, StatusCode::BAD_REQUEST);
    assert!(body_wn1["message"]
        .as_str()
        .unwrap()
        .contains("Mật khẩu phải bao gồm"));

    // 3. Weak new password (missing uppercase) -> 400 Bad Request
    let weak_new_2 = json!({
        "currentPassword": "InitialPassword123!",
        "newPassword": "nouppercase123!"
    });
    let (status_wn2, _) = send_request(
        &app,
        "POST",
        "/api/Account/change-password",
        Some(token),
        Some(weak_new_2),
    )
    .await;
    assert_eq!(status_wn2, StatusCode::BAD_REQUEST);

    // 4. Missing / unauthenticated token -> 401 Unauthorized
    let valid_change = json!({
        "currentPassword": "InitialPassword123!",
        "newPassword": "ValidNewPassword456@"
    });
    let (status_unauth, _) = send_request(
        &app,
        "POST",
        "/api/Account/change-password",
        None,
        Some(valid_change.clone()),
    )
    .await;
    assert_eq!(status_unauth, StatusCode::UNAUTHORIZED);

    // 5. Successful change
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

    // 6. Old password must fail login immediately
    let old_login = json!({
        "usernameOrEmail": "pw_edge@example.com",
        "password": "InitialPassword123!"
    });
    let (old_status, _) =
        send_request(&app, "POST", "/api/Account/login", None, Some(old_login)).await;
    assert_eq!(old_status, StatusCode::UNAUTHORIZED);

    // 7. New password must succeed login immediately
    let new_login = json!({
        "usernameOrEmail": "pw_edge_user",
        "password": "ValidNewPassword456@"
    });
    let (new_status, new_body) =
        send_request(&app, "POST", "/api/Account/login", None, Some(new_login)).await;
    assert_eq!(new_status, StatusCode::OK);
    assert!(new_body["token"].is_string());

    // 8. User deleted from database attempting password change with previously valid token -> 404
    sqlx::query("DELETE FROM users WHERE email = 'pw_edge@example.com'")
        .execute(&pool)
        .await
        .unwrap();

    let change_deleted = json!({
        "currentPassword": "ValidNewPassword456@",
        "newPassword": "AnotherPassword789!"
    });
    let (status_del, body_del) = send_request(
        &app,
        "POST",
        "/api/Account/change-password",
        Some(token),
        Some(change_deleted),
    )
    .await;
    assert_eq!(status_del, StatusCode::NOT_FOUND);
    assert!(body_del["message"]
        .as_str()
        .unwrap()
        .contains("Người dùng không tồn tại"));
}

// =========================================================================
// 4. Cross-Client Alias Routes Full Matrix
// =========================================================================

#[tokio::test]
async fn test_adv_cross_client_alias_routes_matrix() {
    let (app, _pool) = setup_test_app().await;

    // Matrix of Register Routes:
    // /api/Account/register, /api/account/register, /api/auth/register
    let register_routes = vec![
        "/api/Account/register",
        "/api/account/register",
        "/api/auth/register",
    ];

    let mut user_tokens = Vec::new();

    for (idx, route) in register_routes.into_iter().enumerate() {
        let payload = json!({
            "email": format!("alias_reg_{}@example.com", idx),
            "password": "SecurePassword123!",
            "username": format!("alias_reg_user_{}", idx),
            "displayName": format!("Alias User {}", idx)
        });

        let (status, body) = send_request(&app, "POST", route, None, Some(payload)).await;
        assert!(
            status == StatusCode::OK || status == StatusCode::CREATED,
            "Register route '{}' failed with status: {}",
            route,
            status
        );
        assert!(body["token"].is_string());
        user_tokens.push((
            format!("alias_reg_{}@example.com", idx),
            body["token"].as_str().unwrap().to_string(),
        ));
    }

    // Matrix of Login Routes:
    // /api/Account/login, /api/account/login, /api/auth/login
    let login_routes = vec![
        "/api/Account/login",
        "/api/account/login",
        "/api/auth/login",
    ];

    for (idx, route) in login_routes.into_iter().enumerate() {
        let email = format!("alias_reg_{}@example.com", idx);
        let payload = json!({
            "usernameOrEmail": email,
            "password": "SecurePassword123!"
        });

        let (status, body) = send_request(&app, "POST", route, None, Some(payload)).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "Login route '{}' failed with status: {}",
            route,
            status
        );
        assert!(body["token"].is_string());
    }

    // Matrix of Profile GET Routes:
    // /api/Account/profile, /api/account/profile, /api/auth/profile
    let profile_get_routes = vec![
        "/api/Account/profile",
        "/api/account/profile",
        "/api/auth/profile",
    ];

    let sample_token = &user_tokens[0].1;

    for route in profile_get_routes {
        let (status, body) = send_request(&app, "GET", route, Some(sample_token), None).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "Profile GET route '{}' failed with status: {}",
            route,
            status
        );
        assert_eq!(body["email"], user_tokens[0].0);
    }

    // Matrix of Profile PUT Routes:
    // /api/Account/update-profile, /api/account/update-profile, /api/auth/profile
    let profile_put_routes = vec![
        "/api/Account/update-profile",
        "/api/account/update-profile",
        "/api/auth/profile",
    ];

    for (idx, route) in profile_put_routes.into_iter().enumerate() {
        let payload = json!({
            "displayName": format!("Updated via Route {}", idx)
        });

        let (status, body) =
            send_request(&app, "PUT", route, Some(sample_token), Some(payload)).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "Profile PUT route '{}' failed with status: {}",
            route,
            status
        );
        assert_eq!(body["success"], true);

        // Verify update took effect
        let (_, prof) =
            send_request(&app, "GET", "/api/Account/profile", Some(sample_token), None).await;
        assert_eq!(prof["displayName"], format!("Updated via Route {}", idx));
    }

    // Matrix of Change Password Routes:
    // /api/Account/change-password, /api/account/change-password
    let change_pwd_routes = vec![
        "/api/Account/change-password",
        "/api/account/change-password",
    ];

    let mut current_pwd = "SecurePassword123!".to_string();
    for (idx, route) in change_pwd_routes.into_iter().enumerate() {
        let new_pwd = format!("NewAliasPassword{}!#", idx);
        let payload = json!({
            "currentPassword": current_pwd,
            "newPassword": new_pwd
        });

        let (status, body) =
            send_request(&app, "POST", route, Some(sample_token), Some(payload)).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "Change password route '{}' failed with status: {}",
            route,
            status
        );
        assert_eq!(body["success"], true);
        current_pwd = new_pwd;
    }

    // Matrix of Upgrade to VIP Routes:
    // /api/Account/upgrade-to-vip, /api/account/upgrade-to-vip
    let upgrade_routes = vec![
        "/api/Account/upgrade-to-vip",
        "/api/account/upgrade-to-vip",
    ];

    for route in upgrade_routes {
        let (status, body) = send_request(&app, "POST", route, Some(sample_token), None).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "Upgrade to VIP route '{}' failed with status: {}",
            route,
            status
        );
        assert_eq!(body["role"], "VIP");
    }
}

// =========================================================================
// 5. User Lifecycle & State Transitions
// =========================================================================

#[tokio::test]
async fn test_adv_user_state_transitions_full_lifecycle() {
    let (app, pool) = setup_test_app().await;

    // State 1: Anonymous -> Register
    let reg_payload = json!({
        "email": "lifecycle@example.com",
        "password": "PasswordLifecycle123!",
        "username": "lifecycle_user",
        "displayName": "Lifecycle User"
    });
    let (reg_status, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    assert!(reg_status == StatusCode::OK || reg_status == StatusCode::CREATED);
    let user_id = reg_body["userId"].as_i64().unwrap();
    let initial_token = reg_body["token"].as_str().unwrap();

    // Verify initial role in DB is 'User' and is_active is 1
    let row = sqlx::query("SELECT role, is_active FROM users WHERE id = ?")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    let role: String = row.get("role");
    let is_active: i64 = row.get("is_active");
    assert_eq!(role, "User");
    assert_eq!(is_active, 1);

    // State 2: Verify Initial Profile reflects role 'User'
    let (_, prof) =
        send_request(&app, "GET", "/api/Account/profile", Some(initial_token), None).await;
    assert_eq!(prof["role"], "User");
    assert_eq!(prof["isActive"], true);

    // State 3: Transition to VIP Role
    let (vip_status, vip_body) = send_request(
        &app,
        "POST",
        "/api/Account/upgrade-to-vip",
        Some(initial_token),
        None,
    )
    .await;
    assert_eq!(vip_status, StatusCode::OK);
    assert_eq!(vip_body["role"], "VIP");

    // Profile confirms VIP
    let (_, prof_vip) =
        send_request(&app, "GET", "/api/Account/profile", Some(initial_token), None).await;
    assert_eq!(prof_vip["role"], "VIP");

    // Idempotent VIP upgrade
    let (vip_status_again, _) = send_request(
        &app,
        "POST",
        "/api/Account/upgrade-to-vip",
        Some(initial_token),
        None,
    )
    .await;
    assert_eq!(vip_status_again, StatusCode::OK);

    // State 4: Transition to Disabled (is_active = 0)
    sqlx::query("UPDATE users SET is_active = 0 WHERE id = ?")
        .bind(user_id)
        .execute(&pool)
        .await
        .unwrap();

    // Login must be rejected with 403 Forbidden
    let login_disabled = json!({
        "usernameOrEmail": "lifecycle@example.com",
        "password": "PasswordLifecycle123!"
    });
    let (dis_status, dis_body) =
        send_request(&app, "POST", "/api/Account/login", None, Some(login_disabled)).await;
    assert_eq!(dis_status, StatusCode::FORBIDDEN);
    assert!(dis_body["message"]
        .as_str()
        .unwrap()
        .contains("Tài khoản đã bị vô hiệu hóa"));

    // State 5: Reactivate account (is_active = 1)
    sqlx::query("UPDATE users SET is_active = 1 WHERE id = ?")
        .bind(user_id)
        .execute(&pool)
        .await
        .unwrap();

    // Login must now succeed with 200 OK
    let login_active = json!({
        "usernameOrEmail": "lifecycle_user",
        "password": "PasswordLifecycle123!"
    });
    let (act_status, act_body) =
        send_request(&app, "POST", "/api/Account/login", None, Some(login_active)).await;
    assert_eq!(act_status, StatusCode::OK);
    assert_eq!(act_body["role"], "VIP"); // Role should still be VIP after reactivation
}

// =========================================================================
// 6. JWT Security, Tampering & Forgery Resistance
// =========================================================================

#[tokio::test]
async fn test_adv_jwt_tampering_and_forgery() {
    let (app, _pool) = setup_test_app().await;

    let reg_payload = json!({
        "email": "jwttest@example.com",
        "password": "PasswordJwt123!",
        "username": "jwttest_user"
    });
    let (_, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    let valid_token = reg_body["token"].as_str().unwrap();

    // Case 1: Tampered token signature
    let mut tampered_token = valid_token.to_string();
    tampered_token.push_str("tampered");
    let (status_tamp, body_tamp) = send_request(
        &app,
        "GET",
        "/api/Account/profile",
        Some(&tampered_token),
        None,
    )
    .await;
    assert_eq!(status_tamp, StatusCode::UNAUTHORIZED);
    assert_eq!(body_tamp["error"], "Unauthorized");

    // Case 2: Forged token signed with attacker secret key
    #[derive(serde::Serialize)]
    struct FakeClaims {
        sub: String,
        email: String,
        role: String,
        exp: usize,
    }
    let fake_claims = FakeClaims {
        sub: "1".to_string(),
        email: "jwttest@example.com".to_string(),
        role: "Admin".to_string(),
        exp: (chrono::Utc::now() + chrono::Duration::hours(1)).timestamp() as usize,
    };
    let forged_token = encode(
        &Header::default(),
        &fake_claims,
        &EncodingKey::from_secret(b"AttackerSecretKey1234567890!@#$"),
    )
    .unwrap();

    let (status_forged, body_forged) = send_request(
        &app,
        "GET",
        "/api/Account/profile",
        Some(&forged_token),
        None,
    )
    .await;
    assert_eq!(status_forged, StatusCode::UNAUTHORIZED);
    assert_eq!(body_forged["error"], "Unauthorized");

    // Case 3: Expired token
    let expired_claims = FakeClaims {
        sub: "1".to_string(),
        email: "jwttest@example.com".to_string(),
        role: "User".to_string(),
        exp: (chrono::Utc::now() - chrono::Duration::hours(1)).timestamp() as usize,
    };
    let expired_token = encode(
        &Header::default(),
        &expired_claims,
        &EncodingKey::from_secret(b"TestSecretKeyForTestingJwtTokensOnly12345!"),
    )
    .unwrap();

    let (status_exp, body_exp) = send_request(
        &app,
        "GET",
        "/api/Account/profile",
        Some(&expired_token),
        None,
    )
    .await;
    assert_eq!(status_exp, StatusCode::UNAUTHORIZED);
    assert_eq!(body_exp["error"], "Unauthorized");
}

// =========================================================================
// 7. Token Duration, Case Insensitivity & Email Boundaries
// =========================================================================

#[tokio::test]
async fn test_adv_remember_me_token_duration() {
    let (app, _pool) = setup_test_app().await;

    let email = "durations@example.com";
    let pwd = "DurationPassword123!";
    let reg_payload = json!({
        "email": email,
        "password": pwd,
        "username": "duration_user"
    });
    let (_, _) = send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;

    // Login with rememberMe = false
    let login_normal = json!({
        "usernameOrEmail": email,
        "password": pwd,
        "rememberMe": false
    });
    let (_, body_normal) = send_request(&app, "POST", "/api/Account/login", None, Some(login_normal)).await;
    let token_normal = body_normal["token"].as_str().unwrap();

    // Login with rememberMe = true
    let login_remember = json!({
        "usernameOrEmail": email,
        "password": pwd,
        "rememberMe": true
    });
    let (_, body_remember) = send_request(&app, "POST", "/api/Account/login", None, Some(login_remember)).await;
    let token_remember = body_remember["token"].as_str().unwrap();

    // Decode claims
    let secret = "TestSecretKeyForTestingJwtTokensOnly12345!";
    let claims_normal = food_tip_be_rust::services::auth_service::verify_jwt(token_normal, secret).unwrap();
    let claims_remember = food_tip_be_rust::services::auth_service::verify_jwt(token_remember, secret).unwrap();

    let now = chrono::Utc::now().timestamp() as usize;
    let normal_diff_secs = claims_normal.exp - now;
    let remember_diff_secs = claims_remember.exp - now;

    // Normal should be approximately 2 hours (7200 seconds)
    assert!(
        (7100..=7300).contains(&normal_diff_secs),
        "Normal token duration unexpected: {}s",
        normal_diff_secs
    );

    // RememberMe should be approximately 30 days (2,592,000 seconds)
    assert!(
        (2500000..=2650000).contains(&remember_diff_secs),
        "RememberMe token duration unexpected: {}s",
        remember_diff_secs
    );
}

#[tokio::test]
async fn test_adv_case_insensitivity_and_whitespace_username() {
    let (app, _pool) = setup_test_app().await;

    // 1. Register with mixed case email and username
    let reg_payload = json!({
        "email": "CaseTester@Domain.Com",
        "password": "PasswordCase123!",
        "username": "CaseHero"
    });
    let (status_reg, _) = send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    assert!(status_reg == StatusCode::OK || status_reg == StatusCode::CREATED);

    // 2. Login via lowercase email
    let (s1, b1) = send_request(&app, "POST", "/api/Account/login", None, Some(json!({
        "usernameOrEmail": "casetester@domain.com",
        "password": "PasswordCase123!"
    }))).await;
    assert_eq!(s1, StatusCode::OK);
    assert_eq!(b1["username"], "CaseHero");

    // 3. Login via uppercase email
    let (s2, b2) = send_request(&app, "POST", "/api/Account/login", None, Some(json!({
        "usernameOrEmail": "CASETESTER@DOMAIN.COM",
        "password": "PasswordCase123!"
    }))).await;
    assert_eq!(s2, StatusCode::OK);
    assert_eq!(b2["username"], "CaseHero");

    // 4. Login via lowercase username
    let (s3, b3) = send_request(&app, "POST", "/api/Account/login", None, Some(json!({
        "usernameOrEmail": "casehero",
        "password": "PasswordCase123!"
    }))).await;
    assert_eq!(s3, StatusCode::OK);
    assert_eq!(b3["username"], "CaseHero");

    // 5. Duplicate register with different case must be rejected
    let dup_payload = json!({
        "email": "casetester@domain.com",
        "password": "PasswordCase123!",
        "username": "different_user"
    });
    let (s_dup, b_dup) = send_request(&app, "POST", "/api/Account/register", None, Some(dup_payload)).await;
    assert_eq!(s_dup, StatusCode::BAD_REQUEST);
    assert!(b_dup["message"].as_str().unwrap().contains("Email đã được sử dụng"));

    // 6. Whitespace username fallback
    let ws_payload = json!({
        "email": "whitespace_test@example.com",
        "password": "PasswordCase123!",
        "username": "     "
    });
    let (s_ws, b_ws) = send_request(&app, "POST", "/api/Account/register", None, Some(ws_payload)).await;
    assert!(s_ws == StatusCode::OK || s_ws == StatusCode::CREATED);
    let generated_username = b_ws["username"].as_str().unwrap();
    assert!(
        generated_username.starts_with("whitespace_test_"),
        "Expected auto-generated username prefix, got {}",
        generated_username
    );
}

#[tokio::test]
async fn test_adv_invalid_email_boundary_rejection() {
    let (app, _pool) = setup_test_app().await;

    // Emails that strictly fail the current validation logic:
    // (len < 5 OR missing '@' OR missing '.')
    let rejected_emails = vec![
        "",
        "   ",
        "plainaddress",
        "missing_dot@domain",
        "username@com",
        "a@b",   // len 3 < 5
        "a@b.",  // len 4 < 5
    ];

    for email in rejected_emails {
        let payload = json!({
            "email": email,
            "password": "PasswordValid123!",
            "username": format!("u_{}", uuid::Uuid::new_v4().simple())
        });
        let (status, body) = send_request(&app, "POST", "/api/Account/register", None, Some(payload)).await;
        assert_eq!(
            status,
            StatusCode::BAD_REQUEST,
            "Invalid email '{}' was unexpectedly accepted! Response: {:?}",
            email,
            body
        );
        assert!(
            body["message"].as_str().unwrap().contains("Email không hợp lệ"),
            "Expected 'Email không hợp lệ' for '{}', got {:?}",
            email,
            body
        );
    }
}

/// Adversarial probe on the naive email validator:
/// The current validator only checks `len >= 5 && contains('@') && contains('.')`.
/// We empirically document that structurally malformed emails like `@missingusername.com`
/// pass registration due to the naive check, which is recorded as an observation/finding.
#[tokio::test]
async fn test_adv_email_validation_naive_boundary_behavior() {
    let (app, _pool) = setup_test_app().await;

    let naive_accepted_emails = vec![
        "@missingusername.com", // missing local-part before @
        "user@domain.",         // trailing dot with empty TLD
    ];

    for email in naive_accepted_emails {
        let payload = json!({
            "email": email,
            "password": "PasswordValid123!",
            "username": format!("u_{}", uuid::Uuid::new_v4().simple())
        });
        let (status, body) = send_request(&app, "POST", "/api/Account/register", None, Some(payload)).await;
        // Empirically confirms that the current naive validator accepts these strings:
        assert!(
            status == StatusCode::OK || status == StatusCode::CREATED,
            "Email '{}' was expected to pass current naive validator, got {}",
            email,
            status
        );
        assert!(body["token"].is_string());
    }
}

