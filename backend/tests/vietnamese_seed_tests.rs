//! Test seed món Việt (`db::seed_vietnamese_recipes`) và dữ liệu `/catalog` trả về.

mod common;

use axum::{body::Body, http::Request};
use food_tip_be_rust::{config::Config, create_app, db, state::AppState};
use http_body_util::BodyExt;
use serde_json::Value;
use tower::ServiceExt;

fn expected_count() -> usize {
    let raw = include_str!("../assets/vietnamese_recipes.json");
    serde_json::from_str::<Vec<Value>>(raw).unwrap().len()
}

#[tokio::test]
async fn seeds_all_vietnamese_recipes_once_on_top_of_spoonacular() {
    let pool = common::setup_test_pool().await;
    assert_eq!(db::seed_database(&pool).await.unwrap(), 8);

    let n = expected_count();
    assert!(n > 1500, "file dữ liệu phải có khoảng 1.800 món, có {n}");
    assert_eq!(db::seed_vietnamese_recipes(&pool).await.unwrap(), n);
    // Chạy lại không thêm trùng.
    assert_eq!(db::seed_vietnamese_recipes(&pool).await.unwrap(), n);

    let total: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipes").fetch_one(&pool).await.unwrap();
    assert_eq!(total.0 as usize, 8 + n);
    let dup_steps: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM (SELECT recipe_id, step_number FROM recipe_instructions GROUP BY 1, 2 HAVING COUNT(*) > 1)",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(dup_steps.0, 0, "không được nhân đôi các bước khi seed lại");
}

#[tokio::test]
async fn vietnamese_recipes_do_not_invent_missing_data() {
    let pool = common::setup_test_pool().await;
    db::seed_vietnamese_recipes(&pool).await.unwrap();

    let fake_nutrition: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM recipe_nutritions WHERE recipe_id >= 1000000")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(fake_nutrition.0, 0, "không có dữ liệu dinh dưỡng thì không tạo dòng dinh dưỡng");

    let invented: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM recipes WHERE id >= 1000000 AND (cook_time_minutes != 0 OR servings != 0 OR total_ratings != 0)",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(invented.0, 0);

    let empty: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM recipes r WHERE id >= 1000000 AND (NOT EXISTS (SELECT 1 FROM recipe_ingredients i WHERE i.recipe_id = r.id) OR NOT EXISTS (SELECT 1 FROM recipe_instructions s WHERE s.recipe_id = r.id))",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(empty.0, 0, "món nào cũng phải có nguyên liệu và các bước");
}

#[tokio::test]
async fn catalog_returns_vietnamese_recipes_with_empty_nutrients() {
    let pool = common::setup_test_pool().await;
    db::seed_database(&pool).await.unwrap();
    db::seed_vietnamese_recipes(&pool).await.unwrap();
    let config = Config {
        port: 0,
        database_url: "sqlite::memory:".into(),
        jwt_secret: "TestSecretKeyForTestingJwtTokensOnly12345!".into(),
        jwt_expiration_hours: 2,
    };
    let app = create_app(AppState::new(pool, config));

    let res = app
        .oneshot(Request::get("/catalog").body(Body::empty()).unwrap())
        .await
        .unwrap();
    assert!(res.status().is_success());
    let items: Vec<Value> = serde_json::from_slice(&res.into_body().collect().await.unwrap().to_bytes()).unwrap();
    assert_eq!(items.len(), 8 + expected_count());

    let pho = items
        .iter()
        .find(|r| r["title"].as_str().unwrap().contains("Phở") && r["id"].as_i64().unwrap() >= 1_000_000)
        .expect("phải có món phở");
    assert_eq!(pho["source"], "Món Ngon Mỗi Ngày");
    assert_eq!(pho["nutrients"], serde_json::json!({}));
    assert_eq!(pho["time"], 0);
    assert!(!pho["steps"].as_array().unwrap().is_empty());
    assert!(!pho["ingredients"].as_array().unwrap().is_empty());
}
