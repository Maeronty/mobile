mod common;

use axum::{
    body::Body,
    http::{header, Request, StatusCode},
    Router,
};
use common::setup_test_app;
use http_body_util::BodyExt;
use serde_json::{json, Value};
use sqlx::SqlitePool;
use tower::ServiceExt;

/// Encode URI components so hyper/Axum parser accepts special characters
/// while preserving query parameters and percent-encoded entities.
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

async fn count_db_recipes(pool: &SqlitePool) -> i64 {
    let (cnt,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes")
        .fetch_one(pool)
        .await
        .expect("Failed to count recipes");
    cnt
}

// =========================================================================
// 1. SQL Injection Attacks in `?term=` (Keyword Search)
// =========================================================================

#[tokio::test]
async fn test_adv_sqli_keyword_search_term() {
    let (app, pool) = setup_test_app().await;
    let initial_count = count_db_recipes(&pool).await;
    assert_eq!(initial_count, 8, "Expected 8 initial recipes in seed db");

    let attack_payloads = [
        // Classic tautology
        "' OR '1'='1",
        "' OR 1=1 --",
        "\" OR \"1\"=\"1",
        "admin' OR '1'='1' --",
        // Table drop / truncation attempts
        "'; DROP TABLE recipes; --",
        "'; DROP TABLE recipe_ingredients; --",
        "'; DELETE FROM recipes; --",
        "test'; UPDATE recipes SET title='HACKED'; --",
        // Union-based exfiltration
        "' UNION SELECT 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15 --",
        "' UNION SELECT tbl_name, sql, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL FROM sqlite_master --",
        "' UNION SELECT email, password_hash, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL FROM users --",
        // Subqueries & time-based / blind simulation
        "' OR EXISTS(SELECT * FROM users WHERE email LIKE '%') --",
        "' AND (SELECT count(*) FROM recipes, recipes, recipes) > 0 --",
        // Null bytes
        "thịt\0bò",
        "thịt%00bò",
        "%00' OR 1=1 --",
        // Comments & weird delimiters
        "';--",
        "/*comment*/",
        "admin'/*",
        "'' OR ''=''",
    ];

    for payload in attack_payloads {
        let uri = format!("/api/Recipes/search?term={}", payload);
        let (status, body) = send_request(&app, "GET", &uri, None, None).await;

        // Must NEVER crash with 500
        assert_ne!(
            status,
            StatusCode::INTERNAL_SERVER_ERROR,
            "Server panic / 500 on SQLi payload: {}",
            payload
        );

        // Should return 200 OK with empty or safely filtered list
        assert_eq!(
            status,
            StatusCode::OK,
            "Expected 200 OK for search query with payload: {}",
            payload
        );

        let items = body.as_array().expect("Body must be a JSON array");
        // No SQL injection should dump all 8 recipes when payload is a tautology
        if payload.contains("' OR '1'='1") || payload.contains("' OR 1=1") {
            assert!(
                items.is_empty(),
                "SQL Injection tautology must not return recipes! Got {} results for payload: {}",
                items.len(),
                payload
            );
        }

        // Check legacy alias route as well
        let alias_uri = format!("/api/recipes/search?term={}", payload);
        let (alias_status, _) = send_request(&app, "GET", &alias_uri, None, None).await;
        assert_eq!(alias_status, StatusCode::OK);
    }

    // Verify database integrity: table and data must be completely intact
    let post_count = count_db_recipes(&pool).await;
    assert_eq!(
        post_count, initial_count,
        "Database recipes table was corrupted or altered by SQL injection attacks!"
    );
}

// =========================================================================
// 2. SQL Injection Attacks in Search by Ingredients
// =========================================================================

#[tokio::test]
async fn test_adv_sqli_search_by_ingredients() {
    let (app, pool) = setup_test_app().await;
    let initial_count = count_db_recipes(&pool).await;

    // 1. Pure malicious SQL payloads (no valid ingredients) -> must return 0 matched recipes
    let pure_sqli_payloads = [
        "UNION SELECT * FROM sqlite_master",
        "'; DROP TABLE recipe_ingredients; --",
        "'; DELETE FROM recipes; --",
        "' OR '1'='1",
        "' OR 1=1 --",
        "admin'--",
    ];

    for payload in pure_sqli_payloads {
        let uri = format!("/api/Recipes/search-by-ingredients?ingredients={}", payload);
        let (status, body) = send_request(&app, "GET", &uri, None, None).await;

        assert_ne!(
            status,
            StatusCode::INTERNAL_SERVER_ERROR,
            "Server 500 panic on ingredient SQLi payload: {}",
            payload
        );
        assert_eq!(status, StatusCode::OK);
        let items = body.as_array().expect("Body must be an array");
        assert!(
            items.is_empty(),
            "Pure SQL injection payload must not match any recipes: {}",
            payload
        );
    }

    // 2. Mixed payloads: valid ingredient + SQL injection attempt
    let mixed_sqli_payloads = [
        ("thịt bò,UNION SELECT * FROM sqlite_master", Some("thịt bò")),
        ("ức gà,'; DROP TABLE recipe_ingredients; --", Some("ức gà")),
        ("hành tây' OR '1'='1,khoai tây", Some("khoai tây")),
        ("thịt%00bò,gà\0nướng", None), // Corrupted with null bytes; safely handled without 500
    ];

    for (payload, expected_token) in mixed_sqli_payloads {
        let uri = format!("/api/Recipes/search-by-ingredients?ingredients={}", payload);
        let (status, body) = send_request(&app, "GET", &uri, None, None).await;

        assert_ne!(
            status,
            StatusCode::INTERNAL_SERVER_ERROR,
            "Server 500 panic on mixed SQLi payload: {}",
            payload
        );
        assert_eq!(status, StatusCode::OK);

        let items = body.as_array().expect("Body must be an array");
        if let Some(token) = expected_token {
            assert!(
                items.iter().any(|item| {
                    item["matchedIngredients"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .any(|m| m.as_str().unwrap().contains(token))
                }),
                "Expected valid token '{}' to be matched in payload '{}'",
                token,
                payload
            );
        }

        // Verify that SQL injection string was not treated as SQL and didn't leak schema
        for item in items {
            let matched_ings = item["matchedIngredients"].as_array().unwrap();
            for m in matched_ings {
                let m_str = m.as_str().unwrap();
                assert!(
                    !m_str.contains("sqlite_master") && !m_str.contains("DROP TABLE"),
                    "SQL injection string leaked into matchedIngredients: {}",
                    m_str
                );
            }
        }
    }

    // Edge cases: empty commas
    let empty_commas = [",,,", " , , , ", "%2C%2C%2C", "   ,   "];
    for payload in empty_commas {
        let uri = format!("/api/Recipes/search-by-ingredients?ingredients={}", payload);
        let (status, body) = send_request(&app, "GET", &uri, None, None).await;

        assert_eq!(
            status,
            StatusCode::BAD_REQUEST,
            "Commas-only ingredient list must return 400 Bad Request: {}",
            payload
        );
        let err_msg = body.get("message").and_then(|m| m.as_str()).unwrap_or("");
        assert!(
            err_msg.contains("Danh sách nguyên liệu"),
            "Error message should mention ingredients list: {}",
            err_msg
        );
    }

    // DB integrity check
    let post_count = count_db_recipes(&pool).await;
    assert_eq!(post_count, initial_count, "Database damaged by SQLi in search-by-ingredients");
}

// =========================================================================
// 3. Unicode, Vietnamese Diacritics & Exotic Input Stress
// =========================================================================

#[tokio::test]
async fn test_adv_unicode_vietnamese_and_exotic_characters() {
    let (app, _pool) = setup_test_app().await;

    // 1. Precomposed (NFC) vs Decomposed (NFD) Unicode
    // Canonical recipe: "Súp Đậu Lăng Đỏ với Gà và Củ Cải"
    let nfc_term = "Súp Đậu Lăng Đỏ"; // NFC
    let nfd_term = "Su\u{0301}p Đa\u{0323}u Lăng Đo\u{0309}"; // NFD decomposed

    let (status_nfc, body_nfc) = send_request(
        &app,
        "GET",
        &format!("/api/Recipes/search?term={}", nfc_term),
        None,
        None,
    )
    .await;
    assert_eq!(status_nfc, StatusCode::OK);
    let items_nfc = body_nfc.as_array().unwrap();
    assert!(
        !items_nfc.is_empty(),
        "NFC search should match 'Súp Đậu Lăng Đỏ'"
    );

    let (status_nfd, body_nfd) = send_request(
        &app,
        "GET",
        &format!("/api/Recipes/search?term={}", nfd_term),
        None,
        None,
    )
    .await;
    // NFD should execute cleanly without 500 or panic
    assert_eq!(status_nfd, StatusCode::OK);
    assert_ne!(status_nfd, StatusCode::INTERNAL_SERVER_ERROR);
    let _ = body_nfd.as_array().expect("Body must be an array");

    // 2. Mixed casing of Vietnamese diacritics
    let case_variations = [
        "thịt bò",
        "THỊT BÒ",
        "ThỊt Bò",
        "tHịT bÒ",
        "Ức Gà",
        "ỨC GÀ",
        "ức gà",
    ];

    for term in case_variations {
        let uri = format!("/api/Recipes/search?term={}", term);
        let (status, body) = send_request(&app, "GET", &uri, None, None).await;
        assert_eq!(status, StatusCode::OK, "Failed on term: {}", term);
        let items = body.as_array().unwrap();
        assert!(
            !items.is_empty(),
            "Expected results for case-insensitive Vietnamese query: {}",
            term
        );
    }

    // 3. Emojis and Multilingual Scripts
    let exotic_terms = [
        "🍲",
        "🥩",
        "🥦",
        "🥕🍲🥘",
        "борщ",
        "суп",
        "ラーメン",
        "شوربة",
        "מרק",
        "🍵 green tea",
    ];

    for term in exotic_terms {
        let uri = format!("/api/Recipes/search?term={}", term);
        let (status, body) = send_request(&app, "GET", &uri, None, None).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "Server failed on emoji/multilingual input: {}",
            term
        );
        assert!(body.is_array());
    }

    // 4. Special Characters, Whitespace, Zero-Width Characters, XSS Injection
    let special_terms = [
        "    thịt       bò     ",
        "\t\tthịt\nbò\r\n",
        "\u{200B}thịt\u{200B}bò\u{200B}", // zero-width spaces
        "\u{FEFF}thịt bò",                 // byte order mark
        "<script>alert('xss')</script>",
        "<img src=x onerror=alert(1)>",
        "{\"term\": \"json_injection\"}",
        "term with 'single' and \"double\" quotes",
        "!@#$%^&*()_+{}|:<>?[];',./",
    ];

    for term in special_terms {
        let uri = format!("/api/Recipes/search?term={}", term);
        let (status, body) = send_request(&app, "GET", &uri, None, None).await;
        assert_ne!(
            status,
            StatusCode::INTERNAL_SERVER_ERROR,
            "Panic on special input: {}",
            term
        );
        assert_eq!(status, StatusCode::OK);
        assert!(body.is_array());
    }
}

// =========================================================================
// 4. Boundary & Corner Cases on Recipe List Query Parameters
// =========================================================================

#[tokio::test]
async fn test_adv_recipe_list_query_parameters_boundaries() {
    let (app, _pool) = setup_test_app().await;

    // 1. Negative maxTime (?maxTime=-1) -> returns empty list []
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes?maxTime=-1", None, None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().expect("Body should be an array");
    assert!(
        items.is_empty(),
        "Negative maxTime should filter out all recipes, got {}",
        items.len()
    );

    // 2. Zero maxTime (?maxTime=0) -> returns empty list []
    let (status, body) = send_request(&app, "GET", "/api/Recipes?maxTime=0", None, None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert!(
        items.is_empty(),
        "Zero maxTime should filter out all recipes"
    );

    // 3. Very large valid i64 maxTime (?maxTime=9999999999999999) -> returns all 8 recipes
    let (status, body) = send_request(
        &app,
        "GET",
        "/api/Recipes?maxTime=9999999999999999",
        None,
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert_eq!(
        items.len(),
        8,
        "Huge maxTime should include all recipes"
    );

    // 4. Overflown integer in query param -> 400 Bad Request, NO 500
    let (status, _) = send_request(
        &app,
        "GET",
        "/api/Recipes?maxTime=99999999999999999999999999999999999999",
        None,
        None,
    )
    .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "Integer overflow in query param must yield 400 Bad Request"
    );

    // 5. Non-numeric maxTime string -> 400 Bad Request, NO 500
    let (status, _) =
        send_request(&app, "GET", "/api/Recipes?maxTime=notanumber", None, None).await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "Non-numeric maxTime must yield 400 Bad Request"
    );

    // 6. Non-existent category -> returns empty list []
    let (status, body) = send_request(
        &app,
        "GET",
        "/api/Recipes?category=KhongTonTai123",
        None,
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert!(
        items.is_empty(),
        "Non-existent category must return empty list"
    );

    // 7. Empty category query param (?category=) -> returns all 8 recipes
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes?category=", None, None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert_eq!(
        items.len(),
        8,
        "Empty category should be ignored and return all recipes"
    );

    // 8. Whitespace-only category (?category=%20%20) -> returns all 8 recipes
    let (status, body) = send_request(
        &app,
        "GET",
        "/api/Recipes?category=%20%20%20",
        None,
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert_eq!(
        items.len(),
        8,
        "Whitespace-only category should be trimmed and return all recipes"
    );

    // 9. Case-insensitive category match
    let (status_lower, body_lower) = send_request(
        &app,
        "GET",
        "/api/Recipes?category=bữa%20trưa",
        None,
        None,
    )
    .await;
    assert_eq!(status_lower, StatusCode::OK);
    let lower_items = body_lower.as_array().unwrap();
    assert!(!lower_items.is_empty());

    let (status_upper, body_upper) = send_request(
        &app,
        "GET",
        "/api/Recipes?category=BỮA%20TRƯA",
        None,
        None,
    )
    .await;
    assert_eq!(status_upper, StatusCode::OK);
    let upper_items = body_upper.as_array().unwrap();
    assert_eq!(
        lower_items.len(),
        upper_items.len(),
        "Category filter should match case-insensitively with Vietnamese diacritics"
    );

    // 10. Multi-filter combination: category AND maxTime
    let (status_combo, body_combo) = send_request(
        &app,
        "GET",
        "/api/Recipes?category=bữa%20trưa&maxTime=30",
        None,
        None,
    )
    .await;
    assert_eq!(status_combo, StatusCode::OK);
    let combo_items = body_combo.as_array().unwrap();
    for item in combo_items {
        let cook_time = item["cookTimeMinutes"].as_i64().unwrap();
        assert!(cook_time <= 30);
    }
}

// =========================================================================
// 5. Recipe Detail ID Boundary & Path Injection Stress
// =========================================================================

#[tokio::test]
async fn test_adv_recipe_detail_id_boundaries() {
    let (app, _pool) = setup_test_app().await;

    // 1. Negative ID (-1) -> 404 Not Found
    let (status, body) = send_request(&app, "GET", "/api/Recipes/-1", None, None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(
        body["message"],
        "Không tìm thấy công thức món ăn."
    );

    // 2. Zero ID (0) -> 404 Not Found
    let (status, body) = send_request(&app, "GET", "/api/Recipes/0", None, None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(
        body["message"],
        "Không tìm thấy công thức món ăn."
    );

    // 3. Minimum i64 (-9223372036854775808) -> 404 Not Found
    let (status, _) = send_request(
        &app,
        "GET",
        &format!("/api/Recipes/{}", i64::MIN),
        None,
        None,
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    // 4. Maximum i64 (9223372036854775807) -> 404 Not Found
    let (status, _) = send_request(
        &app,
        "GET",
        &format!("/api/Recipes/{}", i64::MAX),
        None,
        None,
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    // 5. Overflowing i64 in path -> 400 Bad Request
    let (status, _) = send_request(
        &app,
        "GET",
        "/api/Recipes/9999999999999999999999999999999999",
        None,
        None,
    )
    .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "Overflowing ID in path must yield 400"
    );

    // 6. Non-numeric ID string -> 400 Bad Request
    let non_numeric = [
        "abc",
        "invalid-id",
        "true",
        "null",
        "undefined",
        "715415.5", // float
    ];
    for bad_id in non_numeric {
        let uri = format!("/api/Recipes/{}", bad_id);
        let (status, _) = send_request(&app, "GET", &uri, None, None).await;
        assert_eq!(
            status,
            StatusCode::BAD_REQUEST,
            "Non-numeric ID in path should return 400: {}",
            bad_id
        );
    }

    // 7. SQL injection in path parameter
    let sqli_paths = [
        "/api/Recipes/1%20OR%201=1",
        "/api/Recipes/1;DROP%20TABLE%20recipes;--",
        "/api/Recipes/1'",
        "/api/Recipes/'--",
    ];
    for sqli_path in sqli_paths {
        let (status, _) = send_request(&app, "GET", sqli_path, None, None).await;
        // Should be rejected by Axum Path<i64> deserializer with 400 Bad Request or 404
        assert!(
            status == StatusCode::BAD_REQUEST || status == StatusCode::NOT_FOUND,
            "Expected 400 or 404 for path SQLi, got: {}",
            status
        );
        assert_ne!(
            status,
            StatusCode::INTERNAL_SERVER_ERROR,
            "Path SQLi caused 500 internal server error: {}",
            sqli_path
        );
    }
}

// =========================================================================
// 6. AI Suggest Adversarial Inputs
// =========================================================================

#[tokio::test]
async fn test_adv_ai_suggest_adversarial_inputs() {
    let (app, pool) = setup_test_app().await;
    let initial_count = count_db_recipes(&pool).await;

    // 1. Empty ingredients array -> 400 Bad Request
    let (status, body) = send_request(
        &app,
        "POST",
        "/suggest",
        None,
        Some(json!({ "ingredients": [] })),
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(
        body["message"],
        "Danh sách nguyên liệu không được để trống."
    );

    // 2. Array with empty and whitespace-only strings -> 400 Bad Request
    let (status, body) = send_request(
        &app,
        "POST",
        "/suggest",
        None,
        Some(json!({ "ingredients": ["", "   ", "\t", "\n"] })),
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(
        body["message"],
        "Danh sách nguyên liệu không được để trống."
    );

    // 3. Array with SQL injection payloads in JSON
    let sqli_suggest = json!({
        "ingredients": [
            "'; DROP TABLE recipes; --",
            "' OR '1'='1",
            "UNION SELECT * FROM sqlite_master",
            "thịt bò",
            "hành tây"
        ]
    });
    let (status, body) = send_request(&app, "POST", "/suggest", None, Some(sqli_suggest)).await;
    assert_eq!(status, StatusCode::OK);
    let suggestions = body.as_array().expect("Must return suggestions array");
    assert!(!suggestions.is_empty(), "Should match on 'thịt bò' safely");

    // 4. Large array stress (500 synthetic ingredients)
    let mut large_ings: Vec<String> = (0..500).map(|i| format!("gia_vi_{}", i)).collect();
    large_ings.push("thịt bò".to_string());
    large_ings.push("khoai tây".to_string());

    let (status, body) = send_request(
        &app,
        "POST",
        "/suggest",
        None,
        Some(json!({ "ingredients": large_ings })),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let suggestions = body.as_array().unwrap();
    assert!(!suggestions.is_empty());

    // 5. Malformed JSON payload (type mismatch: string instead of array) -> 422 or 400
    let (status, _) = send_request(
        &app,
        "POST",
        "/suggest",
        None,
        Some(json!({ "ingredients": "not-an-array" })),
    )
    .await;
    assert!(
        status == StatusCode::UNPROCESSABLE_ENTITY || status == StatusCode::BAD_REQUEST,
        "Malformed JSON should return 422 or 400, got {}",
        status
    );

    // 6. DB integrity check
    let post_count = count_db_recipes(&pool).await;
    assert_eq!(post_count, initial_count, "Database damaged by suggest stress");
}

// =========================================================================
// 7. Auth Extractor Adversarial Header Resilience on Recipe Routes
// =========================================================================

#[tokio::test]
async fn test_adv_auth_header_tampering_on_recipe_routes() {
    let (app, _pool) = setup_test_app().await;

    let adversarial_headers = [
        "Bearer malformed.jwt.token",
        "Bearer",
        "Bearer   ",
        "Basic dXNlcjpwYXNz",
        "Bearer ' OR '1'='1",
        "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.tampered_signature",
    ];

    for auth in adversarial_headers {
        let (status, body) = send_request(
            &app,
            "GET",
            "/api/Recipes",
            Some(auth.trim_start_matches("Bearer ")),
            None,
        )
        .await;

        // MaybeAuthUser extractor must gracefully treat invalid auth tokens as guest
        // and return 200 OK with isFavorited = false, NEVER panic or 500
        assert_eq!(
            status,
            StatusCode::OK,
            "Failed gracefully handling bad auth header: {}",
            auth
        );
        let items = body.as_array().unwrap();
        for item in items {
            assert_eq!(
                item["isFavorited"], false,
                "Guest or bad auth must have isFavorited = false"
            );
        }
    }
}
