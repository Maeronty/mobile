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

#[tokio::test]
async fn test_01_catalog_endpoints_and_spoonacular_compatibility() {
    let (app, _pool) = setup_test_app().await;

    let endpoints = [
        "/catalog",
        "/api/catalog",
        "/api/Recipes/catalog",
        "/api/recipes/catalog",
    ];

    for ep in endpoints {
        let (status, body) = send_request(&app, "GET", ep, None, None).await;
        assert_eq!(status, StatusCode::OK, "Failed on endpoint {}", ep);

        let items = body.as_array().expect("Body should be an array");
        assert_eq!(items.len(), 8, "Catalog must return 8 canonical recipes");

        // Verify Spoonacular-compatible fields on the first item
        let first = &items[0];
        assert!(first.get("id").is_some());
        assert!(first.get("title").is_some());
        assert!(first.get("image").is_some());
        assert!(first.get("category").is_some());
        assert!(first.get("servings").is_some());
        assert!(first.get("time").is_some());

        let nutrients = first.get("nutrients").and_then(|n| n.as_object()).unwrap();
        assert!(nutrients.contains_key("Calories"));
        assert!(nutrients.contains_key("Protein"));
        assert!(nutrients.contains_key("Fat"));
        assert!(nutrients.contains_key("Carbohydrates"));

        let steps = first.get("steps").and_then(|s| s.as_array()).unwrap();
        assert!(!steps.is_empty(), "Steps must not be empty");

        let ingredients = first
            .get("ingredients")
            .and_then(|i| i.as_array())
            .unwrap();
        assert!(!ingredients.is_empty(), "Ingredients must not be empty");
        let first_ing = &ingredients[0];
        assert!(first_ing.get("name").is_some());
        assert!(first_ing.get("amount").is_some());
        assert!(first_ing.get("unit").is_some());
    }
}

#[tokio::test]
async fn test_02_recipe_summaries_listing_unauthenticated() {
    let (app, _pool) = setup_test_app().await;

    for path in ["/api/Recipes", "/api/recipes"] {
        let (status, body) = send_request(&app, "GET", path, None, None).await;
        assert_eq!(status, StatusCode::OK);

        let items = body.as_array().expect("Body should be an array");
        assert_eq!(items.len(), 8);

        let item = &items[0];
        let recipe_id = item["recipeId"].as_i64().unwrap();
        let recipe_id_upper = item["recipeID"].as_i64().unwrap();
        let id = item["id"].as_i64().unwrap();

        assert_eq!(recipe_id, recipe_id_upper);
        assert_eq!(recipe_id, id);
        assert!(item["title"].is_string());
        assert!(item["cookTimeMinutes"].is_number());
        assert!(item["difficulty"].is_string());
        assert!(item["averageRating"].is_number());
        assert!(item["category"].is_string());

        let tags = item["tags"].as_array().unwrap();
        assert!(!tags.is_empty());

        let ings = item["ingredientNames"].as_array().unwrap();
        assert!(!ings.is_empty(), "Ingredient names should be populated");

        // Unauthenticated -> isFavorited false, userRating null
        assert_eq!(item["isFavorited"], false);
        assert!(item["userRating"].is_null());
    }
}

#[tokio::test]
async fn test_03_recipe_filtering_by_category() {
    let (app, _pool) = setup_test_app().await;

    // Filter "bữa trưa" -> 4 recipes
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes?category=bữa trưa", None, None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert_eq!(items.len(), 4);
    for item in items {
        assert_eq!(item["category"].as_str().unwrap(), "bữa trưa");
    }

    // Case-insensitivity check: "BỮA TRƯA"
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes?category=BỮA TRƯA", None, None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body.as_array().unwrap().len(), 4);

    // Filter "súp" -> 1 recipe (716406)
    let (status, body) = send_request(&app, "GET", "/api/Recipes?category=súp", None, None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["id"].as_i64().unwrap(), 716406);

    // Filter "món ăn kèm" -> 3 recipes
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes?category=món ăn kèm", None, None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body.as_array().unwrap().len(), 3);

    // Non-existent category -> 0 recipes
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes?category=mon_khong_co", None, None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body.as_array().unwrap().len(), 0);
}

#[tokio::test]
async fn test_04_recipe_filtering_by_max_time() {
    let (app, _pool) = setup_test_app().await;

    // maxTime=30 -> 2 recipes (20 and 30 min)
    let (status, body) = send_request(&app, "GET", "/api/Recipes?maxTime=30", None, None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert_eq!(items.len(), 2);
    for item in items {
        assert!(item["cookTimeMinutes"].as_i64().unwrap() <= 30);
    }

    // maxTime=20 -> 1 recipe (716406)
    let (status, body) = send_request(&app, "GET", "/api/Recipes?maxTime=20", None, None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["id"].as_i64().unwrap(), 716406);

    // Combined category and maxTime: category=bữa trưa and maxTime=55 -> 3 recipes (45, 45, 55 min)
    let (status, body) = send_request(
        &app,
        "GET",
        "/api/Recipes?category=bữa trưa&maxTime=55",
        None,
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert_eq!(items.len(), 3);
}

#[tokio::test]
async fn test_05_recipe_detail_success_and_not_found() {
    let (app, _pool) = setup_test_app().await;

    // Existing recipe 715415
    for path in ["/api/Recipes/715415", "/api/recipes/715415"] {
        let (status, body) = send_request(&app, "GET", path, None, None).await;
        assert_eq!(status, StatusCode::OK);

        assert_eq!(body["recipeId"].as_i64().unwrap(), 715415);
        assert_eq!(body["id"].as_i64().unwrap(), 715415);
        assert_eq!(body["title"].as_str().unwrap(), "Súp Đậu Lăng Đỏ với Gà và Củ Cải");
        assert_eq!(body["servings"].as_i64().unwrap(), 8);
        assert_eq!(body["cookTimeMinutes"].as_i64().unwrap(), 55);
        assert_eq!(body["calories"].as_i64().unwrap(), 477);

        let ings = body["ingredients"].as_array().unwrap();
        assert_eq!(ings.len(), 13);
        assert_eq!(ings[1]["name"].as_str().unwrap(), "cà rốt");

        let instructions = body["instructions"].as_array().unwrap();
        assert_eq!(instructions.len(), 5);
        assert_eq!(instructions[0]["stepNumber"].as_i64().unwrap(), 1);
        assert!(instructions[0]["content"].as_str().unwrap().contains("dầu ô liu"));

        let nutrition = &body["nutrition"];
        assert!(nutrition.is_object());
        assert_eq!(nutrition["calories"].as_f64().unwrap(), 477.24);
        assert_eq!(nutrition["proteinGrams"].as_f64().unwrap(), 26.93);

        assert_eq!(body["isFavorited"], false);
    }

    // Non-existent recipe 999999
    let (status, body) = send_request(&app, "GET", "/api/Recipes/999999", None, None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["message"].as_str().unwrap(), "Không tìm thấy công thức món ăn.");
}

#[tokio::test]
async fn test_06_recipe_keyword_search() {
    let (app, _pool) = setup_test_app().await;

    // Search "bò" -> matches 715446 (Thịt Bò Hầm Nồi Nấu Chậm)
    let (status, body) = send_request(&app, "GET", "/api/Recipes/search?term=bò", None, None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert!(!items.is_empty());
    assert_eq!(items[0]["id"].as_i64().unwrap(), 715446);
    assert!(items[0]["title"].as_str().unwrap().contains("Bò"));

    // Search "gà" -> matches 715415 (Súp Đậu Lăng Đỏ với Gà và Củ Cải)
    let (status, body) = send_request(&app, "GET", "/api/Recipes/search?term=gà", None, None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert!(!items.is_empty());
    assert_eq!(items[0]["id"].as_i64().unwrap(), 715415);

    // Search by ingredient name: "diêm mạch"
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes/search?term=diêm mạch", None, None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["id"].as_i64().unwrap(), 716004);

    // Search unmatched term -> empty array
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes/search?term=nonexistentxyz", None, None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body.as_array().unwrap().len(), 0);

    // Search without term -> empty array
    let (status, body) = send_request(&app, "GET", "/api/Recipes/search", None, None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body.as_array().unwrap().len(), 0);
}

#[tokio::test]
async fn test_07_search_by_ingredients_scoring_and_edge_cases() {
    let (app, _pool) = setup_test_app().await;

    // Search with "thịt bò,hành tây"
    let (status, body) = send_request(
        &app,
        "GET",
        "/api/Recipes/search-by-ingredients?ingredients=thịt bò,hành tây",
        None,
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert!(!items.is_empty());

    let beef_recipe = items
        .iter()
        .find(|item| item["id"].as_i64().unwrap() == 715446)
        .expect("Recipe 715446 should match thịt bò and hành tây");

    assert!(beef_recipe["matchScore"].as_f64().unwrap() > 0.0);
    let matched = beef_recipe["matchedIngredients"].as_array().unwrap();
    assert!(matched.iter().any(|m| m.as_str().unwrap() == "thịt bò"));
    assert!(matched.iter().any(|m| m.as_str().unwrap() == "hành tây"));

    let missing = beef_recipe["missingIngredients"].as_array().unwrap();
    assert!(!missing.is_empty());
    assert!(beef_recipe["reason"].as_str().unwrap().contains("Khớp"));

    // Search with 3 ingredients: thịt bò, hành tây, khoai tây
    let (status, body) = send_request(
        &app,
        "GET",
        "/api/Recipes/search-by-ingredients?ingredients=thịt bò,hành tây,khoai tây",
        None,
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert!(!items.is_empty());

    // Empty query param -> 400 Bad Request
    let (status, body) = send_request(
        &app,
        "GET",
        "/api/Recipes/search-by-ingredients?ingredients=",
        None,
        None,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(
        body["message"].as_str().unwrap(),
        "Danh sách nguyên liệu không được để trống."
    );

    // Omitted ingredients param -> 400 Bad Request
    let (status, body) = send_request(&app, "GET", "/api/Recipes/search-by-ingredients", None, None).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(
        body["message"].as_str().unwrap(),
        "Danh sách nguyên liệu không được để trống."
    );
}

#[tokio::test]
async fn test_08_ai_suggest_endpoint() {
    let (app, _pool) = setup_test_app().await;

    // Valid suggestion request
    for path in ["/suggest", "/api/suggest"] {
        let req_body = json!({
            "ingredients": ["thịt bò", "hành tây", "khoai tây"]
        });
        let (status, body) = send_request(&app, "POST", path, None, Some(req_body)).await;
        assert_eq!(status, StatusCode::OK);

        let suggestions = body.as_array().unwrap();
        assert!(!suggestions.is_empty());

        let first = &suggestions[0];
        assert!(first.get("id").is_some());
        assert!(first.get("title").is_some());
        assert!(first.get("reason").is_some());
        assert!(first["reason"].as_str().unwrap().contains("Món ăn giàu dinh dưỡng"));

        let used = first["used"].as_array().unwrap();
        assert!(!used.is_empty());

        let missing = first["missing"].as_array().unwrap();
        assert!(!missing.is_empty());
    }

    // Empty ingredients array -> 400 Bad Request
    let req_empty = json!({ "ingredients": [] });
    let (status, body) = send_request(&app, "POST", "/suggest", None, Some(req_empty)).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(
        body["message"].as_str().unwrap(),
        "Danh sách nguyên liệu không được để trống."
    );

    // Whitespace-only ingredients -> 400 Bad Request
    let req_whitespace = json!({ "ingredients": ["   ", ""] });
    let (status, body) = send_request(&app, "POST", "/suggest", None, Some(req_whitespace)).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(
        body["message"].as_str().unwrap(),
        "Danh sách nguyên liệu không được để trống."
    );
}

#[tokio::test]
async fn test_09_ingredients_vocabulary_and_stats() {
    let (app, _pool) = setup_test_app().await;

    // Vocabulary endpoint
    for path in ["/api/Recipes/ingredients", "/api/recipes/ingredients"] {
        let (status, body) = send_request(&app, "GET", path, None, None).await;
        assert_eq!(status, StatusCode::OK);

        let items = body.as_array().unwrap();
        assert!(items.len() >= 30, "Should have dozens of unique ingredients");

        let first = &items[0];
        assert!(first.get("ingredientId").is_some());
        assert!(first.get("name").is_some());
        assert!(first.get("createdAt").is_some());
    }

    // Stats endpoint
    for path in ["/api/Recipes/stats", "/api/recipes/stats"] {
        let (status, body) = send_request(&app, "GET", path, None, None).await;
        assert_eq!(status, StatusCode::OK);

        assert_eq!(body["totalRecipes"].as_i64().unwrap(), 8);
        assert!(body["totalIngredients"].as_i64().unwrap() >= 30);
        assert_eq!(body["categoriesCount"].as_i64().unwrap(), 3);
    }
}

#[tokio::test]
async fn test_10_authenticated_vs_unauthenticated_favorite_status() {
    let (app, pool) = setup_test_app().await;

    // 1. Insert a test user into the database
    let user_id = 999_i64;
    sqlx::query(
        r#"
        INSERT INTO users (id, username, email, password_hash, role, created_at, updated_at)
        VALUES (?, 'fav_test_user', 'fav_test@bepviet.vn', 'hash_pw', 'User', '2026-01-01', '2026-01-01')
        "#,
    )
    .bind(user_id)
    .execute(&pool)
    .await
    .unwrap();

    // 2. Unauthenticated check on recipe 715415 and 715446
    let (status, body) = send_request(&app, "GET", "/api/Recipes/715415", None, None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["isFavorited"], false);

    let (status, body) = send_request(&app, "GET", "/api/Recipes", None, None).await;
    assert_eq!(status, StatusCode::OK);
    for item in body.as_array().unwrap() {
        assert_eq!(item["isFavorited"], false);
    }

    // 3. Mark recipe 715415 as favorite in database for this user
    sqlx::query(
        r#"
        INSERT INTO user_favorites (user_id, recipe_id, created_at)
        VALUES (?, 715415, '2026-01-01T10:00:00Z')
        "#,
    )
    .bind(user_id)
    .execute(&pool)
    .await
    .unwrap();

    // 4. Generate valid JWT token for this user
    let token = generate_jwt(
        user_id,
        "fav_test@bepviet.vn",
        "User",
        TEST_SECRET,
        false,
        2,
    )
    .unwrap();

    // 5. Authenticated check on recipe 715415 -> must be favorited
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes/715415", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        body["isFavorited"], true,
        "Recipe 715415 should be marked favorited for authenticated user"
    );

    // 6. Authenticated check on recipe 715446 -> must NOT be favorited
    let (status, body) =
        send_request(&app, "GET", "/api/Recipes/715446", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        body["isFavorited"], false,
        "Recipe 715446 should NOT be marked favorited"
    );

    // 7. Authenticated check on list /api/Recipes
    let (status, body) = send_request(&app, "GET", "/api/Recipes", Some(&token), None).await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    let r_715415 = items
        .iter()
        .find(|i| i["id"].as_i64().unwrap() == 715415)
        .unwrap();
    assert_eq!(r_715415["isFavorited"], true);

    let r_715446 = items
        .iter()
        .find(|i| i["id"].as_i64().unwrap() == 715446)
        .unwrap();
    assert_eq!(r_715446["isFavorited"], false);

    // 8. Authenticated check on search endpoint
    let (status, body) = send_request(
        &app,
        "GET",
        "/api/Recipes/search?term=gà",
        Some(&token),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let items = body.as_array().unwrap();
    assert!(!items.is_empty());
    assert_eq!(items[0]["id"].as_i64().unwrap(), 715415);
    assert_eq!(items[0]["isFavorited"], true);
}
