mod common;

use axum::{
    body::Body,
    http::{header, Request, StatusCode},
    Router,
};
use chrono::Utc;
use common::setup_test_app;
use food_tip_be_rust::services::auth_service::Claims;
use http_body_util::BodyExt;
use jsonwebtoken::{encode, EncodingKey, Header};
use serde_json::{json, Value};
use tokio::task::JoinSet;
use tower::ServiceExt;

const TEST_JWT_SECRET: &str = "TestSecretKeyForTestingJwtTokensOnly12345!";

async fn send_request(
    app: &Router,
    method: &str,
    uri: &str,
    raw_auth_header: Option<&str>,
    body: Option<Value>,
) -> (StatusCode, Value) {
    let mut builder = Request::builder()
        .method(method)
        .uri(uri)
        .header(header::CONTENT_TYPE, "application/json");

    if let Some(auth_val) = raw_auth_header {
        builder = builder.header(header::AUTHORIZATION, auth_val);
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

fn craft_custom_jwt(user_id: &str, email: &str, role: &str, secret: &str, exp: usize) -> String {
    let claims = Claims {
        sub: user_id.to_string(),
        email: email.to_string(),
        role: role.to_string(),
        exp,
    };
    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .expect("Failed to encode JWT")
}

// ============================================================================
// FOCUS AREA 1: Token Security & Attacks
// ============================================================================

#[tokio::test]
async fn test_adversarial_tampered_signature() {
    let (app, _pool) = setup_test_app().await;

    // 1. Register a genuine user
    let reg_payload = json!({
        "email": "tamper_sig@example.com",
        "password": "SecurePassword123!",
        "username": "tampersiguser"
    });
    let (reg_status, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    assert_eq!(reg_status, StatusCode::OK);
    let valid_token = reg_body["token"].as_str().unwrap();

    // Split token: header.payload.signature
    let parts: Vec<&str> = valid_token.split('.').collect();
    assert_eq!(parts.len(), 3, "Valid JWT must have 3 segments");

    // Tamper the signature by mutating characters
    let mut tampered_sig = parts[2].to_string();
    if tampered_sig.ends_with('A') {
        tampered_sig.replace_range(tampered_sig.len() - 1.., "B");
    } else {
        tampered_sig.replace_range(tampered_sig.len() - 1.., "A");
    }
    let tampered_token = format!("{}.{}.{}", parts[0], parts[1], tampered_sig);

    let auth_header = format!("Bearer {}", tampered_token);
    let (status, body) = send_request(&app, "GET", "/api/Account/profile", Some(&auth_header), None).await;

    assert_eq!(
        status,
        StatusCode::UNAUTHORIZED,
        "Tampered signature must return 401 Unauthorized"
    );
    assert_eq!(body["message"], "Vui lòng đăng nhập để tiếp tục.");
    assert_eq!(body["error"], "Unauthorized");
}

#[tokio::test]
async fn test_adversarial_tampered_payload() {
    let (app, _pool) = setup_test_app().await;

    let reg_payload = json!({
        "email": "tamper_payload@example.com",
        "password": "SecurePassword123!",
        "username": "tamperpayload"
    });
    let (reg_status, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    assert_eq!(reg_status, StatusCode::OK);
    let valid_token = reg_body["token"].as_str().unwrap();

    let parts: Vec<&str> = valid_token.split('.').collect();
    assert_eq!(parts.len(), 3);

    // Tamper the payload part
    let mut tampered_payload = parts[1].to_string();
    if tampered_payload.starts_with('e') {
        tampered_payload.replace_range(..1, "f");
    } else {
        tampered_payload.replace_range(..1, "e");
    }
    let tampered_token = format!("{}.{}.{}", parts[0], tampered_payload, parts[2]);

    let auth_header = format!("Bearer {}", tampered_token);
    let (status, body) = send_request(&app, "GET", "/api/Account/profile", Some(&auth_header), None).await;

    assert_eq!(
        status,
        StatusCode::UNAUTHORIZED,
        "Tampered payload must return 401 Unauthorized"
    );
    assert_eq!(body["message"], "Vui lòng đăng nhập để tiếp tục.");
    assert_eq!(body["error"], "Unauthorized");
}

#[tokio::test]
async fn test_adversarial_expired_token() {
    let (app, _pool) = setup_test_app().await;

    // Generate token with expiration 1 hour in the past
    let past_exp = (Utc::now().timestamp() - 3600) as usize;
    let expired_token = craft_custom_jwt("1", "expired@example.com", "User", TEST_JWT_SECRET, past_exp);

    let auth_header = format!("Bearer {}", expired_token);
    let (status, body) = send_request(&app, "GET", "/api/Account/profile", Some(&auth_header), None).await;

    assert_eq!(
        status,
        StatusCode::UNAUTHORIZED,
        "Expired token must return 401 Unauthorized"
    );
    assert_eq!(body["message"], "Vui lòng đăng nhập để tiếp tục.");
    assert_eq!(body["error"], "Unauthorized");
}

#[tokio::test]
async fn test_adversarial_wrong_secret_key() {
    let (app, _pool) = setup_test_app().await;

    let evil_secret = "CompletelyWrongAttackerSecretKey999999999!";
    let future_exp = (Utc::now().timestamp() + 3600) as usize;
    let forged_token = craft_custom_jwt("1", "admin@example.com", "Admin", evil_secret, future_exp);

    let auth_header = format!("Bearer {}", forged_token);
    let (status, body) = send_request(&app, "GET", "/api/Account/profile", Some(&auth_header), None).await;

    assert_eq!(
        status,
        StatusCode::UNAUTHORIZED,
        "Token with wrong secret key must return 401 Unauthorized"
    );
    assert_eq!(body["message"], "Vui lòng đăng nhập để tiếp tục.");
    assert_eq!(body["error"], "Unauthorized");
}

#[tokio::test]
async fn test_adversarial_missing_and_malformed_auth_headers() {
    let (app, _pool) = setup_test_app().await;

    let valid_exp = (Utc::now().timestamp() + 3600) as usize;
    let valid_token = craft_custom_jwt("1", "user@example.com", "User", TEST_JWT_SECRET, valid_exp);

    // List of adversarial and malformed header variations
    let malformed_headers: Vec<(&str, Option<String>)> = vec![
        ("Missing header", None),
        ("Empty header string", Some("".to_string())),
        ("Just 'Bearer ' with empty token", Some("Bearer ".to_string())),
        ("Just 'Bearer' without space", Some("Bearer".to_string())),
        ("Basic auth scheme", Some("Basic dXNlcjpwYXNz".to_string())),
        ("Raw token without Bearer prefix", Some(valid_token.clone())),
        ("Token scheme instead of Bearer", Some(format!("Token {}", valid_token))),
        ("Lowercase bearer scheme", Some(format!("bearer {}", valid_token))),
        ("Uppercase BEARER scheme", Some(format!("BEARER {}", valid_token))),
        ("Bearer with random junk", Some("Bearer this_is_not_a_valid_jwt_at_all".to_string())),
        ("Bearer with single dot", Some("Bearer part1.part2".to_string())),
        ("Bearer with four parts", Some("Bearer a.b.c.d".to_string())),
        ("Bearer with excessive spaces", Some("Bearer    token_with_too_many_spaces".to_string())),
        ("Bearer with punctuation symbols", Some("Bearer !@#$%^&*()_+~`|}{[]:;?><,./".to_string())),
    ];

    for (desc, header_val) in malformed_headers {
        let (status, body) =
            send_request(&app, "GET", "/api/Account/profile", header_val.as_deref(), None).await;

        assert_eq!(
            status,
            StatusCode::UNAUTHORIZED,
            "Malformed auth header '{}' should have returned 401 Unauthorized, but got {}",
            desc,
            status
        );
        assert_eq!(
            body["message"],
            "Vui lòng đăng nhập để tiếp tục.",
            "Malformed auth header '{}' did not return expected message",
            desc
        );
        assert_eq!(body["error"], "Unauthorized");
    }
}

#[tokio::test]
async fn test_adversarial_nonexistent_user_id_in_valid_token() {
    let (app, _pool) = setup_test_app().await;

    // Validly signed token pointing to non-existent user ID 99999
    let future_exp = (Utc::now().timestamp() + 3600) as usize;
    let ghost_token = craft_custom_jwt("99999", "ghost@example.com", "User", TEST_JWT_SECRET, future_exp);
    let auth_header = format!("Bearer {}", ghost_token);

    // 1. GET /api/Account/profile -> 404 Not Found
    let (status_get, body_get) =
        send_request(&app, "GET", "/api/Account/profile", Some(&auth_header), None).await;
    assert_eq!(
        status_get,
        StatusCode::NOT_FOUND,
        "Nonexistent user profile must return 404, got {}",
        status_get
    );
    assert!(
        body_get["message"].as_str().unwrap().contains("Người dùng không tồn tại"),
        "Unexpected message: {:?}",
        body_get
    );

    // 2. PUT /api/Account/update-profile -> 404 Not Found
    let update_payload = json!({ "displayName": "Ghost User" });
    let (status_put, body_put) = send_request(
        &app,
        "PUT",
        "/api/Account/update-profile",
        Some(&auth_header),
        Some(update_payload),
    )
    .await;
    assert_eq!(status_put, StatusCode::NOT_FOUND);
    assert!(body_put["message"].as_str().unwrap().contains("Người dùng không tồn tại"));

    // 3. POST /api/Account/change-password -> 404 Not Found
    let change_pwd_payload = json!({
        "currentPassword": "AnyPassword123!",
        "newPassword": "NewStrongPassword456@"
    });
    let (status_pwd, body_pwd) = send_request(
        &app,
        "POST",
        "/api/Account/change-password",
        Some(&auth_header),
        Some(change_pwd_payload),
    )
    .await;
    assert_eq!(status_pwd, StatusCode::NOT_FOUND);
    assert!(body_pwd["message"].as_str().unwrap().contains("Người dùng không tồn tại"));
}

#[tokio::test]
async fn test_adversarial_malformed_sub_claims() {
    let (app, _pool) = setup_test_app().await;
    let future_exp = (Utc::now().timestamp() + 3600) as usize;

    // Sub claim is not an integer
    let invalid_sub_token = craft_custom_jwt(
        "not_a_valid_integer_id",
        "invalid_sub@example.com",
        "User",
        TEST_JWT_SECRET,
        future_exp,
    );
    let auth_header = format!("Bearer {}", invalid_sub_token);

    let (status, body) = send_request(&app, "GET", "/api/Account/profile", Some(&auth_header), None).await;
    assert_eq!(
        status,
        StatusCode::UNAUTHORIZED,
        "Non-integer sub claim must return 401 Unauthorized"
    );
    assert!(
        body["message"].as_str().unwrap().contains("ID người dùng không hợp lệ"),
        "Unexpected message: {:?}",
        body
    );

    // Negative sub claim
    let negative_sub_token = craft_custom_jwt("-500", "negative@example.com", "User", TEST_JWT_SECRET, future_exp);
    let auth_negative = format!("Bearer {}", negative_sub_token);
    let (status_neg, _) =
        send_request(&app, "GET", "/api/Account/profile", Some(&auth_negative), None).await;
    assert_eq!(status_neg, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn test_adversarial_sql_injection_defense() {
    let (app, _pool) = setup_test_app().await;

    // Injection vectors against login
    let injections = vec![
        "' OR '1'='1",
        "admin' --",
        "' UNION SELECT 1, 'admin', 'admin@example.com', 'hash', 'Admin', NULL, 1, 'Admin', '', '' --",
        "1; DROP TABLE users; --",
        "\" or \"\"=\"",
    ];

    for inj in injections {
        let payload = json!({
            "usernameOrEmail": inj,
            "password": "Password123!"
        });

        let (status, body) =
            send_request(&app, "POST", "/api/Account/login", None, Some(payload)).await;

        assert_eq!(
            status,
            StatusCode::UNAUTHORIZED,
            "SQL injection input '{}' breached auth or failed to return 401",
            inj
        );
        assert!(
            body["message"]
                .as_str()
                .unwrap()
                .contains("Email/tên đăng nhập hoặc mật khẩu không chính xác"),
            "SQL injection input '{}' returned unexpected response: {:?}",
            inj,
            body
        );
    }
}

// ============================================================================
// FOCUS AREA 2: Concurrency & Stress Testing
// ============================================================================

#[tokio::test]
async fn test_adversarial_concurrent_registrations_distinct() {
    let (app, pool) = setup_test_app().await;
    let concurrency = 8;

    let mut set = JoinSet::new();

    for i in 0..concurrency {
        let app = app.clone();
        set.spawn(async move {
            let payload = json!({
                "email": format!("concurrent_distinct_{}@example.com", i),
                "password": "SecurePassword123!",
                "username": format!("concurrent_user_{}", i),
                "displayName": format!("Concurrent User {}", i)
            });

            let (status, body) =
                send_request(&app, "POST", "/api/Account/register", None, Some(payload)).await;
            (status, body)
        });
    }

    let mut success_count = 0;
    while let Some(res) = set.join_next().await {
        let (status, body) = res.expect("Task panicked during concurrent registration");
        assert!(
            status == StatusCode::OK || status == StatusCode::CREATED,
            "Registration failed with status {}: {:?}",
            status,
            body
        );
        assert!(body["token"].is_string());
        assert!(body["userId"].as_i64().is_some());
        success_count += 1;
    }

    assert_eq!(
        success_count, concurrency,
        "All distinct registrations should have succeeded"
    );

    // Verify row count in SQLite
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE email LIKE 'concurrent_distinct_%'")
        .fetch_one(&pool)
        .await
        .expect("Failed to query user count");
    assert_eq!(count.0, concurrency as i64);
}

#[tokio::test]
async fn test_adversarial_concurrent_duplicate_registration_race() {
    let (app, pool) = setup_test_app().await;
    let racers = 8;

    let target_email = "race_victim@example.com";
    let target_username = "race_victim";

    let mut set = JoinSet::new();

    for _ in 0..racers {
        let app = app.clone();
        set.spawn(async move {
            let payload = json!({
                "email": target_email,
                "password": "SecurePassword123!",
                "username": target_username,
                "displayName": "Race Victim"
            });

            let (status, body) =
                send_request(&app, "POST", "/api/Account/register", None, Some(payload)).await;
            (status, body)
        });
    }

    let mut success_count = 0;
    let mut rejected_count = 0;

    while let Some(res) = set.join_next().await {
        let (status, body) = res.expect("Task panicked during race condition test");
        if status == StatusCode::OK || status == StatusCode::CREATED {
            success_count += 1;
            assert!(body["token"].is_string());
        } else {
            rejected_count += 1;
            // Rejections must be graceful 400 Bad Request or 500 SQLite unique violation; never panic/corrupt
            assert!(
                status == StatusCode::BAD_REQUEST || status == StatusCode::INTERNAL_SERVER_ERROR,
                "Unexpected status on race loser: {}",
                status
            );
        }
    }

    assert_eq!(
        success_count, 1,
        "Exactly ONE concurrent registration must succeed for identical email/username"
    );
    assert_eq!(
        rejected_count,
        racers - 1,
        "All other racers must be rejected"
    );

    // Confirm SQLite integrity: exactly 1 row exists
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE email = ?")
        .bind(target_email)
        .fetch_one(&pool)
        .await
        .expect("Failed to query user count");
    assert_eq!(count.0, 1, "Exactly 1 user row must exist in the database");
}

#[tokio::test]
async fn test_adversarial_concurrent_logins_stress() {
    let (app, _pool) = setup_test_app().await;

    // Register a user first
    let reg_payload = json!({
        "email": "stress_login@example.com",
        "password": "SecurePassword123!",
        "username": "stress_login_user"
    });
    let (reg_status, _) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    assert_eq!(reg_status, StatusCode::OK);

    let concurrency = 8;
    let mut set = JoinSet::new();

    for i in 0..concurrency {
        let app = app.clone();
        set.spawn(async move {
            // Alternate between email and username identifier
            let identifier = if i % 2 == 0 {
                "stress_login@example.com"
            } else {
                "stress_login_user"
            };

            let payload = json!({
                "usernameOrEmail": identifier,
                "password": "SecurePassword123!"
            });

            let (status, body) =
                send_request(&app, "POST", "/api/Account/login", None, Some(payload)).await;
            (status, body)
        });
    }

    let mut login_success_count = 0;
    let mut login_fail_count = 0;
    while let Some(res) = set.join_next().await {
        let (status, body) = res.expect("Task panicked during concurrent login");
        if status == StatusCode::OK {
            login_success_count += 1;
        } else {
            login_fail_count += 1;
            println!("Login task failed: status={}, body={:?}", status, body);
        }
    }
    println!("Logins: {} succeeded, {} failed", login_success_count, login_fail_count);
    assert_eq!(
        login_fail_count, 0,
        "Zero concurrent logins should fail"
    );
}

#[tokio::test]
async fn test_adversarial_concurrent_password_change_and_logins() {
    let (app, _pool) = setup_test_app().await;

    let initial_pwd = "OldPassword123!";
    let new_pwd = "NewSecurePassword456@";

    let reg_payload = json!({
        "email": "pwd_stress@example.com",
        "password": initial_pwd,
        "username": "pwd_stress_user"
    });
    let (reg_status, reg_body) =
        send_request(&app, "POST", "/api/Account/register", None, Some(reg_payload)).await;
    assert_eq!(reg_status, StatusCode::OK);
    let token = reg_body["token"].as_str().unwrap().to_string();

    let mut set = JoinSet::new();

    // Spawn 1 password change task
    let app_chg = app.clone();
    let token_chg = token.clone();
    set.spawn(async move {
        let auth_hdr = format!("Bearer {}", token_chg);
        let chg_payload = json!({
            "currentPassword": initial_pwd,
            "newPassword": new_pwd
        });
        let (status, body) = send_request(
            &app_chg,
            "POST",
            "/api/Account/change-password",
            Some(&auth_hdr),
            Some(chg_payload),
        )
        .await;
        ("change_pwd", status, body)
    });

    // Spawn 4 login attempts with old password
    for _ in 0..4 {
        let app_log = app.clone();
        set.spawn(async move {
            let login_payload = json!({
                "usernameOrEmail": "pwd_stress@example.com",
                "password": initial_pwd
            });
            let (status, body) =
                send_request(&app_log, "POST", "/api/Account/login", None, Some(login_payload)).await;
            ("login_old", status, body)
        });
    }

    // Spawn 4 login attempts with new password
    for _ in 0..4 {
        let app_log = app.clone();
        set.spawn(async move {
            let login_payload = json!({
                "usernameOrEmail": "pwd_stress@example.com",
                "password": new_pwd
            });
            let (status, body) =
                send_request(&app_log, "POST", "/api/Account/login", None, Some(login_payload)).await;
            ("login_new", status, body)
        });
    }

    // Collect all results; none should panic or return 500
    while let Some(res) = set.join_next().await {
        let (action, status, body) = res.expect("Task panicked during concurrent password change test");
        match action {
            "change_pwd" => {
                assert_eq!(status, StatusCode::OK, "Password change must succeed: {:?}", body);
            }
            "login_old" => {
                // Before change: 200, After change: 401. Never 500.
                assert!(
                    status == StatusCode::OK || status == StatusCode::UNAUTHORIZED,
                    "Old password login gave unexpected status {}: {:?}",
                    status,
                    body
                );
            }
            "login_new" => {
                // Before change: 401, After change: 200. Never 500.
                assert!(
                    status == StatusCode::OK || status == StatusCode::UNAUTHORIZED,
                    "New password login gave unexpected status {}: {:?}",
                    status,
                    body
                );
            }
            _ => panic!("Unknown action"),
        }
    }

    // Final verification: after all concurrency settles, new password must work 100%, old must fail 100%
    let (final_old_status, _) = send_request(
        &app,
        "POST",
        "/api/Account/login",
        None,
        Some(json!({
            "usernameOrEmail": "pwd_stress@example.com",
            "password": initial_pwd
        })),
    )
    .await;
    assert_eq!(final_old_status, StatusCode::UNAUTHORIZED);

    let (final_new_status, final_new_body) = send_request(
        &app,
        "POST",
        "/api/Account/login",
        None,
        Some(json!({
            "usernameOrEmail": "pwd_stress@example.com",
            "password": new_pwd
        })),
    )
    .await;
    assert_eq!(final_new_status, StatusCode::OK);
    assert!(final_new_body["token"].is_string());
}
