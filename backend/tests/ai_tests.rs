//! Test tính năng AI (`/api/Ai/*`). Không gọi Gemini/Spoonacular thật: dựng một
//! server giả bằng axum trên cổng ngẫu nhiên và trỏ `AiConfig` về đó.

mod common;

use std::sync::{Arc, Mutex};
use std::time::Duration;

use axum::{
    body::Body,
    extract::{Path, Query, State},
    http::{header, HeaderMap, Request, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use base64::Engine;
use food_tip_be_rust::{
    config::Config,
    create_app,
    services::ai_service::AiConfig,
    state::AppState,
};
use http_body_util::BodyExt;
use serde_json::{json, Value};
use tower::ServiceExt;

const JPEG: &[u8] = &[0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
const PNG: &[u8] = b"\x89PNG\r\n\x1a\n\0\0\0\0\0\0\0\0";

/// Kịch bản cho server Gemini giả: mỗi lần gọi lấy phần tử đầu danh sách.
/// `Ok(json)` = trả kết quả; `Err(status)` = trả mã lỗi HTTP.
#[derive(Clone, Default)]
struct Fake {
    gemini: Arc<Mutex<Vec<Result<Value, u16>>>>,
    gemini_calls: Arc<Mutex<Vec<(String, Value)>>>,
    spoonacular: Arc<Mutex<Option<Value>>>,
    spoonacular_query: Arc<Mutex<Option<String>>>,
}

async fn fake_gemini(
    State(fake): State<Fake>,
    Path(_model): Path<String>,
    headers: HeaderMap,
    Json(body): Json<Value>,
) -> Response {
    let key = headers.get("x-goog-api-key").unwrap().to_str().unwrap().to_string();
    fake.gemini_calls.lock().unwrap().push((key, body));
    let next = {
        let mut queue = fake.gemini.lock().unwrap();
        if queue.is_empty() { Err(500) } else { queue.remove(0) }
    };
    match next {
        Ok(output) => Json(json!({
            "candidates": [{ "content": { "parts": [{ "text": output.to_string() }] } }]
        }))
        .into_response(),
        Err(status) => (StatusCode::from_u16(status).unwrap(), [("retry-after", "120")], "{}").into_response(),
    }
}

async fn fake_spoonacular(
    State(fake): State<Fake>,
    Query(q): Query<std::collections::HashMap<String, String>>,
) -> Response {
    *fake.spoonacular_query.lock().unwrap() = q.get("ingredients").cloned();
    match fake.spoonacular.lock().unwrap().clone() {
        Some(v) => Json(v).into_response(),
        None => (StatusCode::PAYMENT_REQUIRED, "{}").into_response(),
    }
}

async fn start_fake(fake: Fake) -> String {
    let app = Router::new()
        .route("/v1beta/models/:model", post(fake_gemini))
        .route("/recipes/findByIngredients", get(fake_spoonacular))
        .layer(axum::extract::DefaultBodyLimit::disable())
        .with_state(fake);
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    format!("http://{addr}")
}

async fn setup(fake: &Fake, keys: &[&str], spoonacular_key: Option<&str>) -> Router {
    let base = start_fake(fake.clone()).await;
    let pool = common::setup_test_pool().await;
    let config = Config {
        port: 0,
        database_url: "sqlite::memory:".to_string(),
        jwt_secret: "TestSecretKeyForTestingJwtTokensOnly12345!".to_string(),
        jwt_expiration_hours: 2,
    };
    let ai = AiConfig {
        gemini_api_keys: keys.iter().map(|k| k.to_string()).collect(),
        gemini_model: "test-model".to_string(),
        gemini_base_url: base.clone(),
        spoonacular_api_key: spoonacular_key.map(str::to_string),
        spoonacular_base_url: base,
        request_timeout: Duration::from_secs(10),
    };
    create_app(AppState::with_ai(pool, config, ai))
}

async fn send(app: &Router, uri: &str, token: Option<&str>, body: Value) -> (StatusCode, Value) {
    let mut req = Request::builder()
        .method("POST")
        .uri(uri)
        .header(header::CONTENT_TYPE, "application/json");
    if let Some(t) = token {
        req = req.header(header::AUTHORIZATION, format!("Bearer {t}"));
    }
    let res = app
        .clone()
        .oneshot(req.body(Body::from(serde_json::to_vec(&body).unwrap())).unwrap())
        .await
        .unwrap();
    let status = res.status();
    let bytes = res.into_body().collect().await.unwrap().to_bytes();
    (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null))
}

async fn login(app: &Router) -> String {
    let (status, body) = send(
        app,
        "/api/Account/register",
        None,
        json!({ "email": "ai_user@example.com", "password": "Password123!", "displayName": "AI" }),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
    body["token"].as_str().unwrap().to_string()
}

fn image(bytes: &[u8], mime: &str) -> Value {
    json!({ "mime": mime, "data": base64::engine::general_purpose::STANDARD.encode(bytes) })
}

#[tokio::test]
async fn ai_routes_require_login() {
    let fake = Fake::default();
    let app = setup(&fake, &["k1"], Some("s")).await;
    let (status, _) = send(&app, "/api/Ai/recognize", None, image(JPEG, "image/jpeg")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    let (status, _) = send(&app, "/api/Ai/suggest", None, json!({ "ingredients": ["trứng"] })).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert!(fake.gemini_calls.lock().unwrap().is_empty());
}

#[tokio::test]
async fn recognize_sends_image_and_dedupes() {
    let fake = Fake::default();
    fake.gemini.lock().unwrap().push(Ok(json!(["Cà chua", "cà chua ", "Trứng gà", ""])));
    let app = setup(&fake, &["k1"], None).await;
    let token = login(&app).await;

    let (status, body) = send(&app, "/api/Ai/recognize", Some(&token), image(JPEG, "image/jpeg")).await;

    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body, json!(["Cà chua", "Trứng gà"]));
    let calls = fake.gemini_calls.lock().unwrap();
    let parts = &calls[0].1["contents"][0]["parts"];
    assert_eq!(parts[1]["inline_data"]["mime_type"], "image/jpeg");
}

#[tokio::test]
async fn recognize_rejects_wrong_or_fake_images() {
    let fake = Fake::default();
    let app = setup(&fake, &["k1"], None).await;
    let token = login(&app).await;

    for body in [
        image(PNG, "image/jpeg"),                          // khai JPEG nhưng là PNG
        image(b"<html></html>", "text/html"),              // không phải ảnh
        json!({ "mime": "image/jpeg", "data": "không phải base64!" }),
    ] {
        let (status, res) = send(&app, "/api/Ai/recognize", Some(&token), body).await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "{res}");
        assert!(res["message"].is_string());
    }
    assert!(fake.gemini_calls.lock().unwrap().is_empty());
}

#[tokio::test]
async fn recognize_accepts_images_larger_than_axum_default_limit() {
    let fake = Fake::default();
    fake.gemini.lock().unwrap().push(Ok(json!([])));
    let app = setup(&fake, &["k1"], None).await;
    let token = login(&app).await;

    let mut big = JPEG.to_vec();
    big.resize(2_500_000, 0); // ~3.3 MB sau base64, vượt 2 MB mặc định của axum
    let (status, body) = send(&app, "/api/Ai/recognize", Some(&token), image(&big, "image/jpeg")).await;
    assert_eq!(status, StatusCode::OK, "{body}");
}

#[tokio::test]
async fn suggest_keeps_only_spoonacular_ids_once() {
    let fake = Fake::default();
    let dish = json!({ "id": 42, "title": "Trứng luộc", "reason": "Dùng trứng sẵn có.", "used": ["1 quả trứng"], "missing": [] });
    fake.gemini.lock().unwrap().extend([
        Ok(json!(["egg"])),
        Ok(json!([{ "id": 99, "title": "Món bịa", "reason": "", "used": [], "missing": [] }, dish, dish])),
    ]);
    *fake.spoonacular.lock().unwrap() = Some(json!([{
        "id": 42, "title": "Boiled egg",
        "usedIngredients": [{ "original": "1 egg" }], "missedIngredients": []
    }]));
    let app = setup(&fake, &["k1"], Some("spoon-key")).await;
    let token = login(&app).await;

    let (status, body) = send(&app, "/api/Ai/suggest", Some(&token), json!({ "ingredients": ["trứng"] })).await;

    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body, json!([dish]));
    assert_eq!(fake.spoonacular_query.lock().unwrap().as_deref(), Some("egg"));
}

#[tokio::test]
async fn suggest_validates_input() {
    let fake = Fake::default();
    let app = setup(&fake, &["k1"], Some("s")).await;
    let token = login(&app).await;
    let too_many: Vec<String> = (0..31).map(|i| format!("món {i}")).collect();
    for ingredients in [json!([]), json!(too_many), json!(["  "])] {
        let (status, _) = send(&app, "/api/Ai/suggest", Some(&token), json!({ "ingredients": ingredients })).await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
    }
}

#[tokio::test]
async fn suggest_reports_missing_spoonacular_key_and_quota() {
    let fake = Fake::default();
    fake.gemini.lock().unwrap().push(Ok(json!(["egg"])));
    let app = setup(&fake, &["k1"], None).await;
    let token = login(&app).await;
    let (status, body) = send(&app, "/api/Ai/suggest", Some(&token), json!({ "ingredients": ["trứng"] })).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert!(body["message"].as_str().unwrap().contains("SPOONACULAR_API_KEY"));

    // Có key nhưng Spoonacular trả 402 (hết hạn mức ngày) → 429.
    let fake = Fake::default();
    fake.gemini.lock().unwrap().push(Ok(json!(["egg"])));
    let app = setup(&fake, &["k1"], Some("s")).await;
    let token = login(&app).await;
    let (status, _) = send(&app, "/api/Ai/suggest", Some(&token), json!({ "ingredients": ["trứng"] })).await;
    assert_eq!(status, StatusCode::TOO_MANY_REQUESTS);
}

#[tokio::test]
async fn gemini_rotates_keys_on_429_and_skips_them_during_cooldown() {
    let fake = Fake::default();
    fake.gemini.lock().unwrap().extend([Err(429), Ok(json!(["Trứng"])), Ok(json!(["Cà chua"]))]);
    let app = setup(&fake, &["a", "b"], None).await;
    let token = login(&app).await;

    let (status, body) = send(&app, "/api/Ai/recognize", Some(&token), image(JPEG, "image/jpeg")).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    let (status, _) = send(&app, "/api/Ai/recognize", Some(&token), image(JPEG, "image/jpeg")).await;
    assert_eq!(status, StatusCode::OK);

    let keys: Vec<String> = fake.gemini_calls.lock().unwrap().iter().map(|(k, _)| k.clone()).collect();
    assert_eq!(keys, ["a", "b", "b"], "key 'a' bị 429 phải được bỏ qua ở lần gọi sau");
}

#[tokio::test]
async fn gemini_all_keys_limited_returns_429() {
    let fake = Fake::default();
    fake.gemini.lock().unwrap().extend([Err(429), Err(429)]);
    let app = setup(&fake, &["a", "b"], None).await;
    let token = login(&app).await;
    let (status, _) = send(&app, "/api/Ai/recognize", Some(&token), image(JPEG, "image/jpeg")).await;
    assert_eq!(status, StatusCode::TOO_MANY_REQUESTS);
}

#[tokio::test]
async fn gemini_single_key_retries_once_on_503() {
    let fake = Fake::default();
    fake.gemini.lock().unwrap().extend([Err(503), Ok(json!(["Hành lá"]))]);
    let app = setup(&fake, &["only"], None).await;
    let token = login(&app).await;
    let (status, body) = send(&app, "/api/Ai/recognize", Some(&token), image(JPEG, "image/jpeg")).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body, json!(["Hành lá"]));
    assert_eq!(fake.gemini_calls.lock().unwrap().len(), 2);
}

#[tokio::test]
async fn without_gemini_key_returns_503() {
    let fake = Fake::default();
    let app = setup(&fake, &[], None).await;
    let token = login(&app).await;
    let (status, body) = send(&app, "/api/Ai/recognize", Some(&token), image(JPEG, "image/jpeg")).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert!(body["message"].as_str().unwrap().contains("GEMINI_API_KEYS"));
}
