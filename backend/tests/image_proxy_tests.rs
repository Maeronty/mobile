//! Test proxy ảnh `/api/image`: chỉ cho tải hộ ảnh từ host được phép.

mod common;

use axum::{body::Body, http::{Request, StatusCode}};
use food_tip_be_rust::handlers::image::is_allowed_image_url;
use tower::ServiceExt;

#[test]
fn only_https_allowed_hosts_are_proxied() {
    assert!(is_allowed_image_url("https://monngonmoingay.com/wp-content/uploads/2019/03/pho.jpg"));
    assert!(is_allowed_image_url("https://img.spoonacular.com/recipes/644387-312x231.jpg"));

    for bad in [
        "http://monngonmoingay.com/a.jpg",               // không phải https
        "https://evil.com/a.jpg",                        // host lạ
        "https://monngonmoingay.com.evil.com/a.jpg",     // giả mạo đuôi
        "https://evilmonngonmoingay.com/a.jpg",          // giả mạo đầu
        "https://monngonmoingay.com:8443/a.jpg",         // cổng tuỳ ý
        "https://127.0.0.1/a.jpg",
        "file:///etc/passwd",
        "không phải url",
    ] {
        assert!(!is_allowed_image_url(bad), "{bad} không được phép");
    }
}

#[tokio::test]
async fn proxy_rejects_disallowed_url_without_fetching() {
    let (app, _pool) = common::setup_test_app().await;
    let res = app
        .oneshot(
            Request::get("/api/image?url=http%3A%2F%2F127.0.0.1%3A8787%2Fhealth")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), StatusCode::BAD_REQUEST);
}
