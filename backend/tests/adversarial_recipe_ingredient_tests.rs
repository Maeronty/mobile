mod common;

use std::collections::HashSet;
use std::time::Instant;

use axum::{
    body::Body,
    http::{header, Request, StatusCode},
    Router,
};
use common::setup_test_app;
use http_body_util::BodyExt;
use regex::Regex;
use serde_json::{json, Value};
use tower::ServiceExt;

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

/// Scenario 1: Percentage matchScore calculation accuracy
/// - verify 0.0 <= matchScore <= 1.0 across diverse input queries
/// - verify that results are strictly ordered descending by matchScore
/// - verify secondary sorting (rating descending when matchScore is tied)
#[tokio::test]
async fn test_01_match_score_bounds_and_descending_ordering() {
    let (app, _pool) = setup_test_app().await;

    let test_queries = [
        "thịt bò",
        "thịt bò,hành tây",
        "thịt bò,hành tây,khoai tây",
        "ức gà,đậu lăng,cà rốt,dầu ô liu,tỏi",
        "thịt bò,nonexistent_item_1,nonexistent_item_2",
        "gạo lứt,đậu phụ,bông cải xanh,nước tương",
        "chuối,dâu tây,sữa chua,mật ong,yến mạch",
    ];

    for q in test_queries {
        let uri = format!("/api/Recipes/search-by-ingredients?ingredients={}", q);
        let (status, body) = send_request(&app, "GET", &uri, None, None).await;
        assert_eq!(status, StatusCode::OK, "Query failed for: {}", q);

        let items = body.as_array().expect("Response must be an array");
        assert!(!items.is_empty(), "Expected matches for: {}", q);

        let mut prev_score = 1.01_f64;
        let mut prev_rating = 5.01_f64;

        for (idx, item) in items.iter().enumerate() {
            let score = item["matchScore"]
                .as_f64()
                .unwrap_or_else(|| panic!("Item at {} missing matchScore: {:?}", idx, item));

            // Verify bounds: 0.0 <= matchScore <= 1.0
            assert!(
                (0.0..=1.0).contains(&score),
                "matchScore {} out of bounds [0.0, 1.0] at index {} for query '{}'",
                score,
                idx,
                q
            );

            let rating = item["averageRating"].as_f64().unwrap_or(0.0);

            // Verify strictly descending by matchScore
            assert!(
                score <= prev_score + 1e-6,
                "Results not sorted descending by matchScore at index {}: prev={}, current={}",
                idx,
                prev_score,
                score
            );

            // Verify tie-breaker: rating descending if scores are identical
            if (score - prev_score).abs() < 1e-6 {
                assert!(
                    rating <= prev_rating + 1e-6,
                    "Tie-breaker violated at index {}: prev_rating={}, current_rating={}",
                    idx,
                    prev_rating,
                    rating
                );
            }

            prev_score = score;
            prev_rating = rating;
        }
    }
}

/// Scenario 2: Breakdown accuracy
/// - verify that matchedIngredients + missingIngredients logic is consistent
/// - verify no duplicate entries in matchedIngredients or missingIngredients
/// - verify no ghost ingredients (not in recipe or input)
#[tokio::test]
async fn test_02_breakdown_accuracy_no_ghost_or_duplicates() {
    let (app, _pool) = setup_test_app().await;

    let query = "thịt bò,hành tây,khoai tây";
    let uri = format!("/api/Recipes/search-by-ingredients?ingredients={}", query);
    let (status, body) = send_request(&app, "GET", &uri, None, None).await;
    assert_eq!(status, StatusCode::OK);

    let items = body.as_array().unwrap();
    assert!(!items.is_empty());

    let user_inputs: HashSet<String> = query.split(',').map(|s| s.to_lowercase()).collect();

    for (idx, item) in items.iter().enumerate() {
        let matched = item["matchedIngredients"]
            .as_array()
            .unwrap_or_else(|| panic!("Item {} missing matchedIngredients", idx));
        let missing = item["missingIngredients"]
            .as_array()
            .unwrap_or_else(|| panic!("Item {} missing missingIngredients", idx));

        // 1. matchedIngredients must not be empty
        assert!(
            !matched.is_empty(),
            "Matched ingredients should not be empty for returned recipe at {}",
            idx
        );

        // 2. Check no duplicates within matchedIngredients
        let mut matched_set = HashSet::new();
        for m in matched {
            let m_str = m.as_str().unwrap().to_lowercase();
            assert!(
                matched_set.insert(m_str.clone()),
                "Duplicate ingredient in matchedIngredients: '{}' at index {}",
                m_str,
                idx
            );
            // Must be one of user input ingredients
            assert!(
                user_inputs.contains(&m_str),
                "Ghost ingredient in matchedIngredients: '{}' not in user inputs",
                m_str
            );
        }

        // 3. Check no duplicates within missingIngredients
        let mut missing_set = HashSet::new();
        for mis in missing {
            let mis_str = mis.as_str().unwrap().to_lowercase();
            assert!(
                missing_set.insert(mis_str.clone()),
                "Duplicate ingredient in missingIngredients: '{}' at index {}",
                mis_str,
                idx
            );
        }

        // 4. No ghost/impossible overlap between matched and missing
        // An ingredient in missing cannot be exact match of user input in matched
        for m in &matched_set {
            assert!(
                !missing_set.contains(m),
                "Ingredient '{}' cannot simultaneously be matched and missing at index {}",
                m,
                idx
            );
        }
    }
}

/// Scenario 3: Reason string format
/// - verify reason string is valid non-empty Vietnamese
/// - verify reason states correct matching count (e.g. "Khớp 2/3 nguyên liệu chính trong tủ lạnh của bạn.")
#[tokio::test]
async fn test_03_reason_string_vietnamese_and_count_format() {
    let (app, _pool) = setup_test_app().await;

    // Regex for search-by-ingredients reason: "Khớp X/Y nguyên liệu chính trong tủ lạnh của bạn."
    let search_reason_re =
        Regex::new(r"^Khớp (\d+)/(\d+) nguyên liệu chính trong tủ lạnh của bạn\.$").unwrap();

    let query = "thịt bò,hành tây,khoai tây";
    let uri = format!("/api/Recipes/search-by-ingredients?ingredients={}", query);
    let (status, body) = send_request(&app, "GET", &uri, None, None).await;
    assert_eq!(status, StatusCode::OK);

    let items = body.as_array().unwrap();
    assert!(!items.is_empty());

    for (idx, item) in items.iter().enumerate() {
        let reason = item["reason"]
            .as_str()
            .unwrap_or_else(|| panic!("Item {} missing reason", idx));

        assert!(!reason.trim().is_empty(), "Reason cannot be empty at {}", idx);

        let caps = search_reason_re
            .captures(reason)
            .unwrap_or_else(|| panic!("Reason format invalid at {}: '{}'", idx, reason));

        let matched_cnt: usize = caps[1].parse().unwrap();
        let total_cnt: usize = caps[2].parse().unwrap();

        let actual_matched_cnt = item["matchedIngredients"].as_array().unwrap().len();
        assert_eq!(
            matched_cnt, actual_matched_cnt,
            "Reason matched count {} doesn't match matchedIngredients.len() {} at {}",
            matched_cnt, actual_matched_cnt, idx
        );
        assert_eq!(
            total_cnt, 3,
            "Reason total count {} doesn't match query ingredients len 3 at {}",
            total_cnt, idx
        );
    }

    // Now verify suggest reason string format: "Tận dụng ... bạn đang có."
    let suggest_req = json!({
        "ingredients": ["thịt bò", "khoai tây"]
    });
    let (status, body) = send_request(&app, "POST", "/suggest", None, Some(suggest_req)).await;
    assert_eq!(status, StatusCode::OK);

    let suggestions = body.as_array().unwrap();
    assert!(!suggestions.is_empty());

    for (idx, item) in suggestions.iter().enumerate() {
        let reason = item["reason"]
            .as_str()
            .unwrap_or_else(|| panic!("Suggestion {} missing reason", idx));

        assert!(
            reason.starts_with("Tận dụng "),
            "Suggestion reason does not start with expected Vietnamese prefix at {}: '{}'",
            idx,
            reason
        );
        assert!(
            reason.ends_with(" bạn đang có."),
            "Suggestion reason does not end with ' bạn đang có.' at {}: '{}'",
            idx,
            reason
        );

        let used = item["used"].as_array().unwrap();
        assert!(!used.is_empty());
        for u in used {
            let u_str = u.as_str().unwrap();
            assert!(
                reason.contains(u_str),
                "Suggestion reason '{}' should contain used ingredient '{}'",
                reason,
                u_str
            );
        }
    }
}

/// Scenario 4: Suggest endpoint adversarial payload: Empty array []
/// - Must return 400 Bad Request
#[tokio::test]
async fn test_04_suggest_empty_array_payload() {
    let (app, _pool) = setup_test_app().await;

    for endpoint in ["/suggest", "/api/suggest"] {
        let req_empty = json!({ "ingredients": [] });
        let (status, body) = send_request(&app, "POST", endpoint, None, Some(req_empty)).await;

        assert_eq!(
            status,
            StatusCode::BAD_REQUEST,
            "Endpoint {} did not return 400 for empty array",
            endpoint
        );
        assert_eq!(
            body["message"].as_str().unwrap_or(""),
            "Danh sách nguyên liệu không được để trống.",
            "Expected Vietnamese validation error message on {}",
            endpoint
        );
    }
}

/// Scenario 5: Suggest endpoint adversarial payload: Array with empty strings ["", "   "]
/// - Must handle gracefully (400 Bad Request or ignoring empty entries)
#[tokio::test]
async fn test_05_suggest_empty_and_whitespace_strings() {
    let (app, _pool) = setup_test_app().await;

    // All empty/whitespace entries -> Must return 400 Bad Request
    let req_all_whitespace = json!({
        "ingredients": ["", "   ", "\t", "\n\r", "   \t   "]
    });
    let (status, body) =
        send_request(&app, "POST", "/suggest", None, Some(req_all_whitespace)).await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "All whitespace array should return 400 Bad Request"
    );
    assert_eq!(
        body["message"].as_str().unwrap_or(""),
        "Danh sách nguyên liệu không được để trống."
    );

    // Mixed entries: valid ingredient with empty/whitespace elements -> Should ignore empty entries and match valid
    let req_mixed = json!({
        "ingredients": ["", "   ", "thịt bò", "  \t  ", "khoai tây", ""]
    });
    let (status, body) = send_request(&app, "POST", "/suggest", None, Some(req_mixed)).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "Mixed array with valid ingredients should succeed"
    );

    let suggestions = body.as_array().unwrap();
    assert!(!suggestions.is_empty(), "Should return suggestions for valid entries");
    for item in suggestions {
        let used = item["used"].as_array().unwrap();
        // Ensure no empty string was treated as a matched ingredient
        for u in used {
            let u_str = u.as_str().unwrap();
            assert!(
                !u_str.trim().is_empty(),
                "used ingredient must not be empty or whitespace"
            );
        }
    }
}

/// Scenario 6: Huge array of 500 ingredients
/// - Must complete quickly without memory leak, stack overflow, or timeout (< 2000ms)
#[tokio::test]
async fn test_06_huge_array_of_500_ingredients_stress() {
    let (app, _pool) = setup_test_app().await;

    let mut huge_ingredients = Vec::with_capacity(500);
    // Include valid real ingredients
    huge_ingredients.push("thịt bò".to_string());
    huge_ingredients.push("khoai tây".to_string());
    huge_ingredients.push("cà rốt".to_string());
    huge_ingredients.push("hành tây".to_string());
    huge_ingredients.push("tỏi".to_string());

    // Fill the rest up to 500 with synthetic ingredient names
    for i in 6..=500 {
        huge_ingredients.push(format!("synthetic_adversarial_ingredient_{:04}", i));
    }
    assert_eq!(huge_ingredients.len(), 500);

    // 1. Stress test POST /suggest with 500 items
    let start_suggest = Instant::now();
    let req_huge = json!({ "ingredients": huge_ingredients });
    let (status, body) = send_request(&app, "POST", "/suggest", None, Some(req_huge)).await;
    let duration_suggest = start_suggest.elapsed();

    assert_eq!(status, StatusCode::OK, "Huge payload POST /suggest failed");
    assert!(
        duration_suggest.as_millis() < 2000,
        "Suggest took too long: {}ms (must be < 2000ms)",
        duration_suggest.as_millis()
    );

    let suggestions = body.as_array().unwrap();
    assert!(
        !suggestions.is_empty(),
        "Should find matches for the 5 real ingredients"
    );

    // 2. Stress test GET /api/Recipes/search-by-ingredients with 500 comma-separated items
    let query_str = huge_ingredients.join(",");
    let start_search = Instant::now();
    let uri = format!("/api/Recipes/search-by-ingredients?ingredients={}", query_str);
    let (status, body) = send_request(&app, "GET", &uri, None, None).await;
    let duration_search = start_search.elapsed();

    assert_eq!(
        status,
        StatusCode::OK,
        "Huge query GET search-by-ingredients failed"
    );
    assert!(
        duration_search.as_millis() < 2000,
        "Search-by-ingredients took too long: {}ms (must be < 2000ms)",
        duration_search.as_millis()
    );

    let items = body.as_array().unwrap();
    assert!(!items.is_empty());
    for item in items {
        let score = item["matchScore"].as_f64().unwrap();
        assert!(
            (0.0..=1.0).contains(&score),
            "Score out of bounds: {}",
            score
        );
        // With 500 ingredients and only a few matches, matchScore must be low (< 0.1)
        assert!(
            score < 0.1,
            "Score {} should be low for 5/500 matches",
            score
        );
    }
}

/// Scenario 7: Duplicate ingredients in request
/// - e.g. ["thịt bò", "thịt bò", "thịt bò"]
/// - Must not inflate matchScore > 1.0
/// - Should deduplicate entries in matchedIngredients / used and not produce repeated names
#[tokio::test]
async fn test_07a_duplicate_ingredients_score_bounds() {
    let (app, _pool) = setup_test_app().await;

    // Search-by-ingredients endpoint with duplicate items
    let uri = "/api/Recipes/search-by-ingredients?ingredients=thịt bò,thịt bò,thịt bò";
    let (status, body) = send_request(&app, "GET", uri, None, None).await;
    assert_eq!(status, StatusCode::OK);

    let items = body.as_array().unwrap();
    assert!(!items.is_empty());

    for item in items {
        let score = item["matchScore"].as_f64().unwrap();
        // Mathematical score must never exceed 1.0
        assert!(
            (0.0..=1.0).contains(&score),
            "matchScore inflated: {}",
            score
        );
    }
}

#[tokio::test]
async fn test_07b_duplicate_ingredients_suggest_deduplication() {
    let (app, _pool) = setup_test_app().await;

    // Suggest endpoint with duplicate items
    let req_duplicates = json!({
        "ingredients": ["thịt bò", "thịt bò", "thịt bò"]
    });
    let (status, body) =
        send_request(&app, "POST", "/suggest", None, Some(req_duplicates)).await;
    assert_eq!(status, StatusCode::OK);

    let suggestions = body.as_array().unwrap();
    assert!(!suggestions.is_empty());

    println!("SUGGEST DUPLICATE RESPONSE: {}", serde_json::to_string_pretty(&suggestions[0]).unwrap());

    for item in suggestions {
        let used = item["used"].as_array().unwrap();
        // Check deduplication in used array
        let mut used_set = HashSet::new();
        for u in used {
            let u_str = u.as_str().unwrap();
            assert!(
                used_set.insert(u_str),
                "used array contains duplicate item: '{}'. Array: {:?}",
                u_str,
                used
            );
        }

        // Reason string should not repeat the same ingredient 3 times
        let reason = item["reason"].as_str().unwrap();
        assert!(
            !reason.contains("thịt bò, thịt bò"),
            "Reason should not repeat duplicate ingredient: '{}'",
            reason
        );
    }
}

#[tokio::test]
async fn test_07c_duplicate_ingredients_search_deduplication() {
    let (app, _pool) = setup_test_app().await;

    // Search-by-ingredients endpoint with duplicate items
    let uri = "/api/Recipes/search-by-ingredients?ingredients=thịt bò,thịt bò,thịt bò";
    let (status, body) = send_request(&app, "GET", uri, None, None).await;
    assert_eq!(status, StatusCode::OK);

    let items = body.as_array().unwrap();
    assert!(!items.is_empty());

    println!("SEARCH DUPLICATE RESPONSE: {}", serde_json::to_string_pretty(&items[0]).unwrap());

    for item in items {
        // matchedIngredients must be deduplicated
        let matched = item["matchedIngredients"].as_array().unwrap();
        let mut matched_set = HashSet::new();
        for m in matched {
            let m_str = m.as_str().unwrap();
            assert!(
                matched_set.insert(m_str),
                "matchedIngredients contains duplicate item: '{}'. Array: {:?}",
                m_str,
                matched
            );
        }
    }
}

/// Scenario 8: Completely unknown / fictional ingredients
/// - e.g. ["kryptonite", "unobtainium", "dilithium"]
/// - Must return 0 matches or empty array without panicking
#[tokio::test]
async fn test_08_completely_unknown_fictional_ingredients() {
    let (app, _pool) = setup_test_app().await;

    let fictional_ings = ["kryptonite", "unobtainium", "dilithium", "vibranium", "mithril"];

    // 1. POST /suggest
    let req_fictional = json!({
        "ingredients": fictional_ings
    });
    let (status, body) =
        send_request(&app, "POST", "/suggest", None, Some(req_fictional)).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "Suggest should return 200 OK without panicking"
    );

    let suggestions = body.as_array().unwrap();
    assert!(
        suggestions.is_empty(),
        "Fictional ingredients should yield 0 suggestions, got {:?}",
        suggestions
    );

    // 2. GET /api/Recipes/search-by-ingredients
    let uri = format!(
        "/api/Recipes/search-by-ingredients?ingredients={}",
        fictional_ings.join(",")
    );
    let (status, body) = send_request(&app, "GET", &uri, None, None).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "search-by-ingredients should return 200 OK without panicking"
    );

    let items = body.as_array().unwrap();
    assert!(
        items.is_empty(),
        "Fictional ingredients should yield 0 matches, got {:?}",
        items
    );
}

/// Scenario 9: Concurrent requests stress
/// - Fire 20 concurrent requests across Tokio tasks to /suggest and /api/Recipes/search-by-ingredients
/// - Verify zero data races and zero SQLite lock contention
#[tokio::test]
async fn test_09_concurrent_requests_stress() {
    let (app, _pool) = setup_test_app().await;

    let mut handles = Vec::new();

    for i in 0..20 {
        let app_clone = app.clone();
        let handle = tokio::spawn(async move {
            if i % 2 == 0 {
                // Call /suggest
                let req = json!({
                    "ingredients": ["thịt bò", "khoai tây", "cà rốt"]
                });
                let (status, body) =
                    send_request(&app_clone, "POST", "/suggest", None, Some(req)).await;
                assert_eq!(status, StatusCode::OK, "Concurrent /suggest failed on task {}", i);
                let arr = body.as_array().expect("Expected array response");
                assert!(!arr.is_empty(), "Expected non-empty suggestions on task {}", i);
            } else {
                // Call /api/Recipes/search-by-ingredients
                let uri = "/api/Recipes/search-by-ingredients?ingredients=ức gà,đậu lăng,cà rốt";
                let (status, body) =
                    send_request(&app_clone, "GET", uri, None, None).await;
                assert_eq!(
                    status,
                    StatusCode::OK,
                    "Concurrent search-by-ingredients failed on task {}",
                    i
                );
                let arr = body.as_array().expect("Expected array response");
                assert!(!arr.is_empty(), "Expected non-empty results on task {}", i);
            }
        });
        handles.push(handle);
    }

    for (i, h) in handles.into_iter().enumerate() {
        let res = h.await;
        assert!(
            res.is_ok(),
            "Concurrent task {} panicked or failed: {:?}",
            i,
            res
        );
    }
}

/// Scenario 10: Adversarial malformed query strings and SQL injection resistance
/// - Only commas / whitespace separators: ",,,,," -> 400 Bad Request
/// - SQL injection attempt in ingredients parameter
#[tokio::test]
async fn test_10_malformed_queries_and_sql_injection_resistance() {
    let (app, _pool) = setup_test_app().await;

    // 1. Only commas in query
    let (status, body) = send_request(
        &app,
        "GET",
        "/api/Recipes/search-by-ingredients?ingredients=,,,,,,,",
        None,
        None,
    )
    .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "Comma-only query should return 400 Bad Request"
    );
    assert_eq!(
        body["message"].as_str().unwrap_or(""),
        "Danh sách nguyên liệu không được để trống."
    );

    // 2. Comma and whitespace only
    let (status, _body) = send_request(
        &app,
        "GET",
        "/api/Recipes/search-by-ingredients?ingredients= , ,  ,   ",
        None,
        None,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);

    // 3. SQL injection attack payload in query string
    let sqli_query = "thịt bò' OR '1'='1; DROP TABLE recipes; --,hành tây";
    let uri = format!("/api/Recipes/search-by-ingredients?ingredients={}", sqli_query);
    let (status, body) = send_request(&app, "GET", &uri, None, None).await;
    // Must succeed without crashing, and MUST NOT execute SQL injection
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert!(!items.is_empty(), "Valid ingredient part 'hành tây' should yield matches");
    // Verify recipes table was NOT dropped by making another standard query
    let (status_check, body_check) =
        send_request(&app, "GET", "/api/Recipes/715446", None, None).await;
    assert_eq!(
        status_check,
        StatusCode::OK,
        "Recipes table was damaged or dropped! SQL injection was not prevented."
    );
    assert_eq!(body_check["id"].as_i64().unwrap(), 715446);
}

#[tokio::test]
async fn test_11_cross_ingredient_false_positives() {
    let (app, _pool) = setup_test_app().await;

    // "thịt heo" (pork) is NOT an ingredient in recipe 715446 (Beef stew which uses "thịt bò")
    // Let's see if querying "thịt heo" matches "Thịt Bò Hầm Nồi Nấu Chậm"
    let uri = "/api/Recipes/search-by-ingredients?ingredients=thịt heo";
    let (status, body) = send_request(&app, "GET", uri, None, None).await;
    assert_eq!(status, StatusCode::OK);

    let items = body.as_array().unwrap();
    println!("SEARCH THỊT HEO (PORK): {}", serde_json::to_string_pretty(&items).unwrap());

    // Recipe 715446 is beef stew with thịt bò. Querying 'thịt heo' (pork) must not match beef stew as a 100% matched ingredient!
    let matched_beef = items.iter().find(|i| i["id"].as_i64().unwrap() == 715446);
    assert!(
        matched_beef.is_none(),
        "CRITICAL BUG: 'thịt heo' (pork) falsely matched beef stew (recipe 715446) due to generic classifier word 'thịt' overlap!"
    );
}

#[tokio::test]
async fn test_12_single_character_substring_explosion() {
    let (app, _pool) = setup_test_app().await;

    // A single letter 't' is not a cooking ingredient
    let uri = "/api/Recipes/search-by-ingredients?ingredients=t";
    let (status, body) = send_request(&app, "GET", uri, None, None).await;
    assert_eq!(status, StatusCode::OK);

    let items = body.as_array().unwrap();
    println!("SEARCH SINGLE LETTER 't': matches {} recipes", items.len());
    // A single letter 't' should not match all 8 recipes in the catalog at 100% score
    assert!(
        items.len() < 8,
        "Single letter query 't' exploded to match all {} recipes in the catalog at 100% matchScore",
        items.len()
    );
}

