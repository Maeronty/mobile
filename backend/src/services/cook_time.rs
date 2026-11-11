//! =============================================================================
//! THỜI GIAN NẤU TỪ NỘI DUNG CÁC BƯỚC
//! =============================================================================
//!
//! VẤN ĐỀ
//!   Món Việt (Món Ngon Mỗi Ngày) không có thời gian nấu → app từng hiện
//!   "— phút" ở mọi món; thời gian từng bước thì bị CHIA ĐỀU giả tạo.
//!   Nhưng nhiều bước có ghi rõ: "ướp để thấm 20 – 30 phút", "để 4h",
//!   "hầm 1 tiếng rưỡi", "ngâm qua đêm".
//!
//! `step_minutes(text)` — thời gian GHI TRONG một bước (None nếu không ghi)
//!   - Số + đơn vị: phút | tiếng | giờ | h ("4h"). "rưỡi" = +30 phút.
//!   - Khoảng "20 – 30 phút" / "20 đến 30 phút" → lấy số lớn (đủ thời gian).
//!   - Phân số "1/2 giờ" → 30 phút. "qua đêm" → 8 giờ.
//!   - Cộng mọi mốc trong bước ("nướng 15 phút ... nướng thêm 15 phút" = 30).
//!
//! `estimate_total(steps)` — tổng ƯỚC LƯỢNG cho cả món (None nếu không bước nào ghi)
//!   1. Bỏ bước "Mách nhỏ" / "Cách dùng": mẹo hay nhắc lại thời gian đã có
//!      ("Ướp thịt trong 4h...") → cộng vào sẽ bị đếm 2 lần.
//!   2. Tổng = các mốc ghi trong bước + 5 phút cho mỗi bước làm thật (Sơ chế /
//!      Thực hiện...) vì thao tác cắt, chiên, xào thường KHÔNG ghi giờ — không
//!      có phần này thì món chiên chỉ ghi "ướp 5 phút" sẽ thành "~5 phút".
//!   3. Làm tròn lên bội số 5. App hiện kèm "~" (`cook_time_estimated = 1`).
//!
//! `backfill_estimates(pool)` — chạy khi khởi động, sau seed
//!   Món có cook_time_minutes = 0 và tính được → ghi số ước lượng + cờ
//!   cook_time_estimated = 1. Món đã có thời gian thật không bị đụng tới; món
//!   không tính được giữ 0 → app ẩn mục thời gian.
//! =============================================================================

use std::collections::HashMap;
use std::sync::OnceLock;

use regex::Regex;
use sqlx::SqlitePool;

use crate::error::AppError;

/// Phút cộng thêm cho mỗi bước làm thật (thao tác không ghi giờ).
const MINUTES_PER_ACTIVE_STEP: i64 = 5;
const OVERNIGHT_MINUTES: f64 = 8.0 * 60.0;

fn duration_regex() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        Regex::new(
            r"(?i)(\d+(?:[.,]\d+)?)(?:\s*/\s*(\d+))?(?:\s*(?:-|–|—|đến|tới)\s*(\d+(?:[.,]\d+)?))?\s*(phút|tiếng|giờ|h)(\s+rưỡi)?\b",
        )
        .expect("regex thời gian hợp lệ")
    })
}

fn parse_number(s: &str) -> f64 {
    s.replace(',', ".").parse().unwrap_or(0.0)
}

/// Bước mẹo / cách dùng — không tính vào tổng thời gian.
fn is_tip_step(text: &str) -> bool {
    let head = text.trim_start().to_lowercase();
    head.starts_with("mách nhỏ") || head.starts_with("cách dùng")
}

/// Thời gian (phút) ghi trong một bước; None nếu bước không ghi.
pub fn step_minutes(text: &str) -> Option<i64> {
    let mut total = 0.0;
    let mut found = false;

    for cap in duration_regex().captures_iter(text) {
        let first = parse_number(&cap[1]);
        let value = match (cap.get(2), cap.get(3)) {
            (Some(den), _) => first / parse_number(den.as_str()).max(1.0),
            (None, Some(upper)) => parse_number(upper.as_str()).max(first),
            (None, None) => first,
        };
        let unit = cap[4].to_lowercase();
        let mut minutes = if unit == "phút" { value } else { value * 60.0 };
        if cap.get(5).is_some() {
            minutes += 30.0;
        }
        if minutes > 0.0 {
            total += minutes;
            found = true;
        }
    }

    if text.to_lowercase().contains("qua đêm") {
        total += OVERNIGHT_MINUTES;
        found = true;
    }

    found.then(|| total.round() as i64)
}

/// Thời gian hiển thị cho từng bước (bỏ bước mẹo / cách dùng).
pub fn displayed_step_minutes(text: &str) -> Option<i64> {
    if is_tip_step(text) {
        None
    } else {
        step_minutes(text)
    }
}

/// Tổng thời gian ước lượng cho cả món; None nếu không bước nào ghi thời gian.
pub fn estimate_total<S: AsRef<str>>(steps: &[S]) -> Option<i64> {
    let work: Vec<&str> = steps.iter().map(AsRef::as_ref).filter(|s| !is_tip_step(s)).collect();
    let written: Vec<i64> = work.iter().filter_map(|s| step_minutes(s)).collect();
    if written.is_empty() {
        return None;
    }
    let total = written.iter().sum::<i64>() + MINUTES_PER_ACTIVE_STEP * work.len() as i64;
    Some((total + 4) / 5 * 5)
}

/// Ghi thời gian ước lượng cho các món chưa có. Trả về số món được cập nhật.
pub async fn backfill_estimates(pool: &SqlitePool) -> Result<usize, AppError> {
    let rows: Vec<(i64, String)> = sqlx::query_as(
        "SELECT i.recipe_id, i.content FROM recipe_instructions i
         JOIN recipes r ON r.id = i.recipe_id
         WHERE r.cook_time_minutes = 0
         ORDER BY i.recipe_id, i.step_number",
    )
    .fetch_all(pool)
    .await?;

    let mut steps: HashMap<i64, Vec<String>> = HashMap::new();
    for (id, content) in rows {
        steps.entry(id).or_default().push(content);
    }

    let mut tx = pool.begin().await?;
    let mut updated = 0;
    for (id, list) in &steps {
        if let Some(minutes) = estimate_total(list) {
            sqlx::query("UPDATE recipes SET cook_time_minutes = ?, cook_time_estimated = 1 WHERE id = ? AND cook_time_minutes = 0")
                .bind(minutes)
                .bind(id)
                .execute(&mut *tx)
                .await?;
            updated += 1;
        }
    }
    tx.commit().await?;

    if updated > 0 {
        tracing::info!("Đã ước lượng thời gian nấu cho {} món từ nội dung các bước.", updated);
    }
    Ok(updated)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn doc_thoi_gian_trong_buoc() {
        assert_eq!(step_minutes("ướp để thấm 20 – 30 phút. Bắp cắt khúc 2cm"), Some(30));
        assert_eq!(step_minutes("nướng 160 độ trong 15 phút ... nướng thêm 15 phút"), Some(30));
        assert_eq!(step_minutes("để 4h cho thịt thấm đều"), Some(240));
        assert_eq!(step_minutes("hầm 1 tiếng rưỡi"), Some(90));
        assert_eq!(step_minutes("ninh 1/2 giờ"), Some(30));
        assert_eq!(step_minutes("ngâm qua đêm"), Some(480));
        assert_eq!(step_minutes("1,5 giờ"), Some(90));
        // Không nhầm đơn vị đo lường / số lượng.
        assert_eq!(step_minutes("1m đường, 2 hộp sữa, 160 độ, cắt 0,3cm"), None);
    }

    #[test]
    fn tong_uoc_luong_bo_buoc_meo() {
        let steps = [
            "Sơ chế: Thịt ba rọi ướp ..., để 4h cho thịt thấm đều",
            "Thực hiện: chiên rám hai mặt ...",
            "Cách dùng: Thịt cắt lát dày khoảng 0,3cm",
            "Mách nhỏ: Ướp thịt trong 4h để thịt hơi lên men chua",
        ];
        // 240 (ướp) + 2 bước làm × 5 = 250 → làm tròn 250.
        assert_eq!(estimate_total(&steps), Some(250));
        assert_eq!(displayed_step_minutes(steps[3]), None);
        assert_eq!(displayed_step_minutes(steps[0]), Some(240));
    }

    #[test]
    fn khong_ghi_thoi_gian_thi_khong_uoc_luong() {
        assert_eq!(estimate_total(&["Sơ chế: rửa rau", "Thực hiện: xào chín"]), None);
    }
}
