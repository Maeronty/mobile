//! Test API danh sách món có phân trang: /api/Recipes/page, /categories, /featured.

mod common;

use std::collections::HashSet;

use axum::{body::Body, http::Request, Router};
use food_tip_be_rust::{config::Config, create_app, db, state::AppState};
use http_body_util::BodyExt;
use serde_json::Value;
use tower::ServiceExt;

async fn app() -> Router {
    let pool = common::setup_test_pool().await;
    db::seed_database(&pool).await.unwrap();
    db::seed_vietnamese_recipes(&pool).await.unwrap();
    let config = Config {
        port: 0,
        database_url: "sqlite::memory:".into(),
        jwt_secret: "TestSecretKeyForTestingJwtTokensOnly12345!".into(),
        jwt_expiration_hours: 2,
    };
    create_app(AppState::new(pool, config))
}

async fn get(app: &Router, uri: &str) -> Value {
    let res = app.clone().oneshot(Request::get(uri).body(Body::empty()).unwrap()).await.unwrap();
    assert!(res.status().is_success(), "{uri} → {}", res.status());
    serde_json::from_slice(&res.into_body().collect().await.unwrap().to_bytes()).unwrap()
}

#[tokio::test]
async fn pages_cover_every_recipe_exactly_once_vietnamese_first() {
    let app = app().await;
    let first = get(&app, "/api/Recipes/page?page=1&pageSize=50").await;
    let total = first["total"].as_i64().unwrap();
    assert!(total > 1500);
    assert_eq!(first["items"].as_array().unwrap().len(), 50);
    assert_eq!(first["hasMore"], true);
    assert!(first["items"][0]["id"].as_i64().unwrap() >= 1_000_000, "món Việt đứng trước");

    let mut seen = HashSet::new();
    let mut page = 1;
    loop {
        let body = get(&app, &format!("/api/Recipes/page?page={page}&pageSize=50")).await;
        for item in body["items"].as_array().unwrap() {
            assert!(seen.insert(item["id"].as_i64().unwrap()), "trùng món giữa các trang");
        }
        if body["hasMore"] == false {
            break;
        }
        page += 1;
    }
    assert_eq!(seen.len() as i64, total, "không được sót món");
}

#[tokio::test]
async fn card_has_only_light_fields() {
    let app = app().await;
    let body = get(&app, "/api/Recipes/page?pageSize=1").await;
    let item = &body["items"][0];
    let mut keys: Vec<&str> = item.as_object().unwrap().keys().map(String::as_str).collect();
    keys.sort();
    assert_eq!(keys, ["calories", "caloriesEstimated", "category", "cookTimeEstimated", "cookTimeMinutes", "id", "image", "ingredientCount", "source", "title"]);
    assert!(item["ingredientCount"].as_i64().unwrap() > 0);
}

#[tokio::test]
async fn filters_by_category_and_vietnamese_search_ignores_case() {
    let app = app().await;
    let canh = get(&app, "/api/Recipes/page?category=Canh&pageSize=50").await;
    assert!(canh["total"].as_i64().unwrap() > 50);
    assert!(canh["items"].as_array().unwrap().iter().all(|i| i["category"] == "Canh"));

    // "phở" viết thường vẫn tìm ra "Phở Bò ..." (LIKE của SQLite không làm được với chữ có dấu).
    let pho = get(&app, "/api/Recipes/page?q=ph%E1%BB%9F").await;
    let items = pho["items"].as_array().unwrap();
    assert!(!items.is_empty());
    assert!(items.iter().all(|i| i["title"].as_str().unwrap().to_lowercase().contains("phở")));
    assert_eq!(pho["total"].as_i64().unwrap() as usize >= items.len(), true);

    let none = get(&app, "/api/Recipes/page?q=khongcomonnay").await;
    assert_eq!(none["total"], 0);
    assert_eq!(none["hasMore"], false);
}

#[tokio::test]
async fn clamps_paging_parameters() {
    let app = app().await;
    let body = get(&app, "/api/Recipes/page?page=0&pageSize=1000").await;
    assert_eq!(body["page"], 1);
    assert_eq!(body["pageSize"], 50);
    let beyond = get(&app, "/api/Recipes/page?page=9999").await;
    assert!(beyond["items"].as_array().unwrap().is_empty());
    assert_eq!(beyond["hasMore"], false);
}

#[tokio::test]
async fn categories_sorted_by_count_other_last_and_featured_has_images() {
    let app = app().await;
    let cats = get(&app, "/api/Recipes/categories").await;
    let cats = cats.as_array().unwrap();
    assert_eq!(cats.last().unwrap()["name"], "Món khác");
    let counts: Vec<i64> = cats[..cats.len() - 1].iter().map(|c| c["count"].as_i64().unwrap()).collect();
    assert!(counts.windows(2).all(|w| w[0] >= w[1]));

    let featured = get(&app, "/api/Recipes/featured").await;
    let featured = featured.as_array().unwrap();
    assert!(featured.len() >= 4);
    assert!(featured.iter().all(|f| !f["image"].as_str().unwrap().is_empty()));
    let cats: HashSet<&str> = featured.iter().map(|f| f["category"].as_str().unwrap()).collect();
    assert_eq!(cats.len(), featured.len(), "mỗi banner một danh mục");
}
