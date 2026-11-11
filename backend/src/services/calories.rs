//! =============================================================================
//! CALO ƯỚC TÍNH CHO CẢ MÓN (từ nguyên liệu × bảng calo)
//! =============================================================================
//!
//! VẤN ĐỀ
//!   Món Việt (Món Ngon Mỗi Ngày) không có dữ liệu dinh dưỡng; nhưng có định
//!   lượng nguyên liệu: "Thịt ba chỉ 300 g", "Trứng gà 2 quả", "Dầu ăn 2 M".
//!
//! FLOW (`estimate_recipe`)
//!   1. Mỗi dòng nguyên liệu có định lượng > 0 (bỏ dòng nhóm "Gia vị: ..."):
//!        a. Tìm nguyên liệu trong `FOODS` — khớp tên DÀI NHẤT chứa trong tên
//!           ("nước cốt dừa" thắng "nước", "dầu hào" thắng "dầu").
//!        b. Đổi định lượng ra gram: g/kg/ml/lít; M = muỗng canh 15 ml,
//!           m = muỗng cà phê 5 ml; chén 200 ml...
//!           Đơn vị "nguyên cái" (quả, trái, củ, con, cái, cây) dùng khối lượng
//!           1 cái của CHÍNH nguyên liệu đó (trứng gà 50 g, vịt 1,5 kg); đơn vị
//!           "một phần" (miếng, lát, lá, tép...) luôn dùng mặc định của đơn vị
//!           — "2 miếng ức vịt" ≠ 2 con vịt, "30 lá dứa" ≠ 30 trái dứa.
//!        c. kcal = gram × kcal/100g.
//!   2. Chỉ trả kết quả khi nhận ra ≥ 60% số dòng có định lượng (và ≥ 2 dòng)
//!      — thiếu nhiều thì con số vô nghĩa → None (app ẩn calo). Tổng > 6000 kcal
//!      cũng coi là không đáng tin (dữ liệu nguồn ghi lạ) → None.
//!   3. Làm tròn tới bội số 10. Đây là calo CẢ MÓN (nguồn không có khẩu phần).
//!
//! NGUỒN SỐ LIỆU
//!   kcal/100g phần ăn được, theo Bảng thành phần thực phẩm Việt Nam (Viện Dinh
//!   dưỡng) và USDA cho vài món nhập, làm tròn. Đây là ƯỚC TÍNH → app hiện "~".
//!
//! `backfill_estimates(pool)` — chạy khi khởi động, sau seed
//!   TÍNH LẠI mọi món chưa có recipe_nutritions (≈ 1.800 món, vài chục ms) →
//!   sửa bảng calo là số liệu cập nhật ngay ở lần chạy sau.
//! =============================================================================

use std::collections::HashMap;

use sqlx::SqlitePool;

use crate::error::AppError;

/// (tên gọi, kcal / 100 g, khối lượng 1 cái/quả/củ... tính bằng g — 0 = dùng mặc định theo đơn vị)
type Food = (&'static [&'static str], f64, f64);

#[rustfmt::skip]
const FOODS: &[Food] = &[
    // --- Thịt ---
    (&["thịt ba chỉ", "ba chỉ", "ba rọi", "thịt ba rọi"], 260.0, 0.0),
    (&["thịt nạc", "nạc vai", "nạc dăm", "thăn heo", "thịt thăn", "cốt lết", "cốt lếch"], 140.0, 0.0),
    (&["thịt heo", "thịt lợn", "thịt đùi"], 200.0, 0.0),
    (&["thịt xay", "thịt băm", "thịt heo xay", "thịt bằm"], 220.0, 0.0),
    (&["sườn non", "sườn heo", "sườn già", "sườn"], 190.0, 0.0),
    (&["giò heo", "chân giò", "móng giò", "chân heo"], 230.0, 0.0),
    (&["da heo"], 300.0, 0.0),
    (&["gan heo", "gan gà", "gan"], 120.0, 0.0),
    (&["xương ống", "xương heo", "xương gà", "xương bò", "xương"], 40.0, 0.0),
    (&["thịt bò", "bò", "bắp bò", "thăn bò", "nạm bò", "phi lê bò"], 120.0, 0.0),
    (&["gầu bò", "ba chỉ bò", "bò mỹ"], 300.0, 0.0),
    (&["bò viên", "gân bò"], 200.0, 15.0),
    (&["thịt gà", "gà ta", "gà công nghiệp", "gà mái", "gà mái dầu", "gà trống", "gà"], 200.0, 1000.0),
    (&["ức gà", "phi lê gà"], 120.0, 200.0),
    (&["đùi gà", "má đùi gà", "thịt đùi gà", "cánh gà", "chân gà"], 190.0, 150.0),
    (&["mề gà", "mề", "lòng gà"], 100.0, 30.0),
    (&["thịt vịt", "vịt"], 267.0, 1500.0),
    (&["ức vịt", "đùi vịt"], 200.0, 300.0),
    (&["thịt dê", "dê"], 125.0, 0.0),
    (&["thịt cừu", "cừu"], 200.0, 0.0),
    (&["ếch"], 90.0, 100.0),
    // --- Hải sản ---
    (&["tôm sú", "tôm thẻ", "tôm càng", "tôm tươi", "tép mỡ", "tôm"], 90.0, 25.0),
    (&["tôm khô"], 347.0, 0.0),
    (&["mực ống", "mực lá", "mực"], 73.0, 150.0),
    (&["mực khô"], 291.0, 0.0),
    (&["bạch tuộc"], 82.0, 0.0),
    (&["cua đồng", "cua"], 103.0, 250.0),
    (&["ghẹ"], 54.0, 200.0),
    (&["nghêu", "sò", "hến", "ốc", "ốc mỡ", "ốc giác", "ốc hương", "ốc bươu", "hàu", "chem chép", "sò điệp"], 70.0, 15.0),
    (&["cá hồi"], 208.0, 0.0),
    (&["cá thu"], 166.0, 0.0),
    (&["cá basa", "cá tra", "cá điêu hồng", "cá rô phi", "cá diêu hồng"], 120.0, 500.0),
    (&["cá lóc", "cá quả", "cá chép", "cá rô", "cá bống", "cá kèo"], 100.0, 500.0),
    (&["cá ngừ"], 130.0, 0.0),
    (&["cá cơm", "cá khô"], 300.0, 0.0),
    (&["cá"], 110.0, 500.0),
    // --- Trứng, chế biến sẵn, đậu hũ ---
    (&["trứng gà", "trứng"], 166.0, 50.0),
    (&["trứng vịt", "trứng vịt lộn", "trứng muối"], 184.0, 70.0),
    (&["trứng cút"], 154.0, 10.0),
    (&["chả lụa", "giò lụa", "giò sống", "chả cá", "mọc"], 140.0, 0.0),
    (&["xúc xích", "hotdog"], 280.0, 50.0),
    (&["lạp xưởng", "lạp xường"], 585.0, 40.0),
    (&["jambon", "thịt nguội", "dăm bông", "ba chỉ xông khói", "thịt xông khói"], 300.0, 20.0),
    (&["pate", "pa tê"], 326.0, 0.0),
    (&["chà bông", "ruốc"], 400.0, 0.0),
    (&["đậu hũ", "đậu phụ", "tàu hũ", "đậu hủ"], 95.0, 100.0),
    (&["tàu hũ ky", "váng đậu"], 400.0, 0.0),
    // --- Tinh bột ---
    (&["gạo", "gạo tẻ", "gạo thơm"], 344.0, 0.0),
    (&["gạo nếp", "nếp"], 346.0, 0.0),
    (&["cơm"], 130.0, 0.0),
    (&["bún"], 110.0, 0.0),
    (&["bánh phở", "phở"], 141.0, 0.0),
    (&["hủ tiếu", "hủ tíu", "bánh canh"], 200.0, 0.0),
    (&["mì gói", "mì ăn liền"], 450.0, 75.0),
    (&["mì trứng", "mì ý", "spaghetti", "nui", "mì"], 350.0, 0.0),
    (&["miến", "bún tàu"], 332.0, 0.0),
    (&["bánh mì sandwich", "bánh mì gối"], 265.0, 30.0),
    (&["bánh mì"], 249.0, 80.0),
    (&["bánh tráng", "bánh đa nem"], 333.0, 10.0),
    (&["bột mì", "bột bánh", "bột đa dụng"], 346.0, 0.0),
    (&["bột năng", "bột sắn", "bột bắp", "bột ngô", "bột gạo", "bột nếp"], 355.0, 0.0),
    (&["bột chiên giòn", "bột chiên xù", "bột tẩm", "bột chiên", "bột tempura", "aji-quick"], 350.0, 0.0),
    (&["khoai tây"], 92.0, 150.0),
    (&["khoai lang"], 119.0, 200.0),
    (&["khoai môn", "khoai sọ", "khoai mỡ", "khoai mỡ tím"], 109.0, 200.0),
    (&["khoai mì", "củ sắn"], 152.0, 300.0),
    (&["bắp mỹ", "bắp", "ngô"], 120.0, 150.0),
    // --- Rau củ, nấm, trái cây ---
    (&["cà rốt"], 39.0, 120.0),
    (&["hành tây"], 41.0, 150.0),
    (&["hành tím", "củ hành", "hành khô", "hành phi"], 40.0, 10.0),
    (&["hành lá", "hành hoa", "hành boaro", "boa rô", "baro"], 25.0, 10.0),
    (&["tỏi"], 121.0, 3.0),
    (&["gừng", "riềng", "nghệ"], 30.0, 20.0),
    (&["sả"], 40.0, 20.0),
    (&["ớt chuông"], 30.0, 150.0),
    (&["ớt"], 37.0, 5.0),
    (&["cà chua bi"], 20.0, 10.0),
    (&["cà chua"], 20.0, 100.0),
    (&["dưa leo", "dưa chuột"], 15.0, 150.0),
    (&["bắp cải", "cải thảo", "cải bắp"], 25.0, 800.0),
    (&["súp lơ", "bông cải"], 30.0, 300.0),
    (&["lá dứa", "lá chanh", "lá lốt", "lá chuối", "lá giang", "lá me", "lá é", "lá nguyệt quế"], 20.0, 2.0),
    (&["cải", "rau muống", "rau dền", "mồng tơi", "rau ngót", "cải ngọt", "cải xanh", "cải bẹ", "rau", "xà lách", "rau thơm", "xà lách mỡ", "ngò", "húng", "tía tô", "kinh giới", "thì là", "cần tây", "rau răm", "lá"], 20.0, 2.0),
    (&["bí đỏ", "bí ngô"], 27.0, 0.0),
    (&["bí xanh", "bí đao", "mướp", "su su", "bầu"], 15.0, 300.0),
    (&["khổ qua", "mướp đắng"], 16.0, 200.0),
    (&["cà tím"], 22.0, 200.0),
    (&["đậu que", "đậu cô ve", "đậu đũa", "đậu hà lan"], 35.0, 0.0),
    (&["đậu bắp"], 38.0, 15.0),
    (&["giá"], 43.0, 0.0),
    (&["củ cải", "su hào", "củ đậu", "củ sen", "ngó sen"], 35.0, 300.0),
    (&["măng"], 20.0, 0.0),
    (&["nấm", "nấm mỡ"], 30.0, 20.0),
    (&["rong biển", "wakame", "rong biểm"], 25.0, 0.0),
    (&["nấm mèo", "mộc nhĩ", "nấm đông cô", "nấm hương"], 280.0, 3.0),
    (&["thơm", "dứa", "khóm"], 29.0, 800.0),
    (&["chanh", "tắc", "quất"], 25.0, 40.0),
    (&["me"], 239.0, 0.0),
    (&["xoài"], 69.0, 300.0),
    (&["chuối"], 90.0, 100.0),
    (&["đu đủ"], 35.0, 500.0),
    (&["táo"], 52.0, 150.0),
    (&["dưa gang", "dưa hấu", "dưa lưới"], 20.0, 1000.0),
    (&["dừa", "cơm dừa"], 368.0, 0.0),
    (&["trái bơ", "quả bơ"], 160.0, 200.0),
    // --- Hạt, đậu khô ---
    (&["đậu phộng", "lạc"], 573.0, 0.0),
    (&["mè", "vừng"], 568.0, 0.0),
    (&["hạt điều"], 605.0, 0.0),
    (&["đậu xanh", "đậu đỏ", "đậu đen", "đậu trắng", "đậu nành"], 330.0, 0.0),
    // --- Chất béo, sữa ---
    (&["dầu ăn", "dầu oliu", "dầu olive", "dầu mè", "dầu điều", "dầu hào hoa", "dầu"], 900.0, 0.0),
    (&["mỡ heo", "mỡ nước", "mỡ"], 896.0, 0.0),
    (&["bơ lạt", "bơ thực vật", "bơ nhạt", "bơ"], 756.0, 0.0),
    (&["nước cốt dừa", "cốt dừa"], 230.0, 0.0),
    (&["sữa đặc"], 336.0, 0.0),
    (&["sữa tươi", "sữa"], 74.0, 0.0),
    (&["sữa chua", "yaourt", "yogurt"], 60.0, 100.0),
    (&["kem tươi", "whipping"], 340.0, 0.0),
    (&["phô mai", "phomai", "cheese"], 380.0, 15.0),
    // --- Gia vị, nước chấm ---
    (&["nước mắm", "mắm"], 50.0, 0.0),
    (&["mắm tôm", "mắm ruốc", "mắm nêm"], 100.0, 0.0),
    (&["nước tương", "xì dầu", "tương"], 60.0, 0.0),
    (&["dầu hào"], 120.0, 0.0),
    (&["tương ớt", "tương cà", "xốt cà", "sốt cà"], 110.0, 0.0),
    (&["mayonnaise", "mayo"], 680.0, 0.0),
    (&["sa tế"], 400.0, 0.0),
    (&["đường", "đường phèn", "đường thốt nốt"], 397.0, 0.0),
    (&["mật ong"], 327.0, 0.0),
    (&["hạt nêm", "bột nêm", "bột canh"], 230.0, 0.0),
    (&["bột ngọt", "muối", "tiêu", "ngũ vị hương", "bột cà ri", "giấm", "bột nghệ", "bột ớt"], 0.0, 0.0),
    (&["rượu", "bia"], 70.0, 0.0),
    (&["nước dừa"], 20.0, 0.0),
    (&["nước dùng", "nước lèo", "nước hầm xương"], 5.0, 0.0),
    (&["nước", "đá"], 0.0, 0.0),
];

/// Trên mức này coi như dữ liệu nguồn ghi lạ → không ước tính.
const MAX_RECIPE_KCAL: f64 = 6000.0;

/// Đơn vị "nguyên cái" → dùng khối lượng 1 cái của chính nguyên liệu (nếu có).
const WHOLE_UNITS: &[&str] = &["trái", "quả", "củ", "con", "cái", "cây"];

/// Khối lượng mặc định (g) của 1 đơn vị đếm khi nguyên liệu không khai báo.
fn default_piece_grams(unit: &str) -> Option<f64> {
    Some(match unit {
        "trái" | "quả" | "củ" => 100.0,
        "củ nhỏ" => 30.0,
        "cây" | "khúc" => 15.0,
        "con" => 200.0,
        "miếng" | "phần" => 100.0,
        "lát" => 15.0,
        "tép" => 3.0,
        "nhánh" | "cọng" => 5.0,
        "tai" => 5.0,
        "lá" => 2.0,
        "cái" | "viên" => 20.0,
        "gói" => 100.0,
        "hộp" => 200.0,
        "bó" | "nắm" => 50.0,
        _ => return None,
    })
}

/// Đổi `amount unit` ra gram cho một nguyên liệu (`piece` = khối lượng 1 cái).
fn to_grams(amount: f64, raw_unit: &str, piece: f64) -> Option<f64> {
    // Bỏ ghi chú trong ngoặc: "gói nhỏ (mua ở...)" → "gói nhỏ".
    let unit = raw_unit.split('(').next().unwrap_or("").trim();
    // Quy ước công thức Việt: "M" = muỗng canh, "m" = muỗng cà phê (phân biệt hoa thường).
    match unit {
        "M" => return Some(amount * 15.0),
        "m" => return Some(amount * 5.0),
        _ => {}
    }
    let u = unit.to_lowercase();
    let per_unit = match u.as_str() {
        "g" | "gr" | "gram" | "gam" | "ml" => 1.0,
        "kg" | "lít" | "lit" | "l" => 1000.0,
        "muỗng canh" | "thìa canh" | "muỗng súp" => 15.0,
        "muỗng cà phê" | "thìa cà phê" | "muỗng cafe" => 5.0,
        "muỗng" | "thìa" => 10.0,
        "chén" => 200.0,
        "bát" | "ly" | "cốc" | "tách" => 250.0,
        "lon" => 330.0,
        "tô" => 500.0,
        _ => {
            // Đơn vị đếm: "củ nhỏ", "trái lớn"... → lấy từ đầu để tra.
            let head = u.split_whitespace().next().unwrap_or("");
            if piece > 0.0 && WHOLE_UNITS.contains(&head) {
                piece
            } else {
                default_piece_grams(&u).or_else(|| default_piece_grams(head))?
            }
        }
    };
    Some(amount * per_unit)
}

/// Nguyên liệu trong bảng khớp tên dài nhất với `name`.
fn find_food(name: &str) -> Option<(f64, f64)> {
    let lower = name.to_lowercase();
    FOODS
        .iter()
        .flat_map(|(aliases, kcal, piece)| aliases.iter().map(move |a| (*a, *kcal, *piece)))
        .filter(|(alias, _, _)| lower.contains(alias))
        .max_by_key(|(alias, _, _)| alias.chars().count())
        .map(|(_, kcal, piece)| (kcal, piece))
}

/// Calo ước tính cho cả món; None nếu nhận ra quá ít nguyên liệu.
pub fn estimate_recipe(ingredients: &[(String, f64, String)]) -> Option<i64> {
    let mut counted = 0usize;
    let mut matched = 0usize;
    let mut kcal = 0.0;

    for (name, amount, unit) in ingredients {
        // Dòng nhóm của dữ liệu cào ("Gia vị: ...") / không định lượng → bỏ qua.
        if *amount <= 0.0 || name.contains(':') {
            continue;
        }
        counted += 1;
        let Some((per100, piece)) = find_food(name) else { continue };
        let Some(grams) = to_grams(*amount, unit, piece) else { continue };
        matched += 1;
        kcal += grams * per100 / 100.0;
    }

    if counted < 2 || (matched as f64) < 0.6 * counted as f64 || !(50.0..=MAX_RECIPE_KCAL).contains(&kcal) {
        return None;
    }
    Some(((kcal / 10.0).round() * 10.0) as i64)
}

/// Ghi calo ước tính cho các món chưa có dữ liệu dinh dưỡng. Trả về số món ghi được.
pub async fn backfill_estimates(pool: &SqlitePool) -> Result<usize, AppError> {
    let rows: Vec<(i64, String, f64, String)> = sqlx::query_as(
        "SELECT i.recipe_id, i.name, i.amount, i.unit FROM recipe_ingredients i
         WHERE NOT EXISTS (SELECT 1 FROM recipe_nutritions n WHERE n.recipe_id = i.recipe_id)
         ORDER BY i.recipe_id, i.sort_order",
    )
    .fetch_all(pool)
    .await?;

    let mut by_recipe: HashMap<i64, Vec<(String, f64, String)>> = HashMap::new();
    for (id, name, amount, unit) in rows {
        by_recipe.entry(id).or_default().push((name, amount, unit));
    }

    let mut tx = pool.begin().await?;
    let mut updated = 0;
    for (id, list) in &by_recipe {
        let kcal = estimate_recipe(list).unwrap_or(0);
        sqlx::query("UPDATE recipes SET estimated_calories = ? WHERE id = ? AND estimated_calories != ?")
            .bind(kcal)
            .bind(id)
            .bind(kcal)
            .execute(&mut *tx)
            .await?;
        if kcal > 0 {
            updated += 1;
        }
    }
    tx.commit().await?;

    if updated > 0 {
        tracing::info!("Đã ước tính calo cho {} món từ nguyên liệu.", updated);
    }
    Ok(updated)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ing(name: &str, amount: f64, unit: &str) -> (String, f64, String) {
        (name.to_string(), amount, unit.to_string())
    }

    #[test]
    fn khop_ten_dai_nhat() {
        assert_eq!(find_food("Nước cốt dừa").unwrap().0, 230.0);
        assert_eq!(find_food("Dầu hào").unwrap().0, 120.0);
        assert_eq!(find_food("Trứng cút luộc").unwrap().0, 154.0);
        assert_eq!(find_food("Hành lá").unwrap().0, 25.0);
        assert_eq!(find_food("Mắm tôm").unwrap().0, 100.0);
        assert_eq!(find_food("Sữa chua không đường").unwrap().0, 60.0);
        assert_eq!(find_food("Aji-Quick® Bột chiên giòn").unwrap().0, 350.0);
        assert!(find_food("Gia vị bí truyền ABC").is_none());
    }

    #[test]
    fn doi_don_vi() {
        assert_eq!(to_grams(2.0, "quả", 50.0), Some(100.0)); // 2 trứng gà
        assert_eq!(to_grams(2.0, "M", 0.0), Some(30.0)); // 2 muỗng canh
        assert_eq!(to_grams(1.0, "m", 0.0), Some(5.0)); // 1 muỗng cà phê
        assert_eq!(to_grams(0.5, "kg", 0.0), Some(500.0));
        assert_eq!(to_grams(1.0, "gói nhỏ xíu (mua ở shop)", 0.0), Some(100.0));
        assert_eq!(to_grams(3.0, "củ nhỏ", 10.0), Some(30.0)); // 3 củ hành tím
        assert_eq!(to_grams(1.0, "", 0.0), None); // không đơn vị → không đoán
        assert_eq!(to_grams(2.0, "miếng", 1500.0), Some(200.0)); // 2 miếng ≠ 2 con
        assert_eq!(to_grams(30.0, "lá", 800.0), Some(60.0)); // 30 lá ≠ 30 trái
    }

    #[test]
    fn ten_de_nham() {
        assert_eq!(find_food("Lá dứa bản lớn").unwrap().0, 20.0);
        assert_eq!(find_food("Gà mái dầu").unwrap().0, 200.0);
        assert_eq!(find_food("Thịt đùi gà").unwrap().0, 190.0);
        assert_eq!(find_food("Ức vịt").unwrap().0, 200.0);
        assert_eq!(find_food("Ốc mỡ").unwrap().0, 70.0);
        assert_eq!(find_food("Khoai mỡ tím").unwrap().0, 109.0);
        assert_eq!(find_food("Nấm mỡ").unwrap().0, 30.0);
        assert_eq!(find_food("Dưa gang muối chua").unwrap().0, 20.0);
        assert_eq!(find_food("Rong biển wakame").unwrap().0, 25.0);
    }

    #[test]
    fn uoc_tinh_mon_ba_chi_chien() {
        let list = vec![
            ing("Thịt ba chỉ", 300.0, "g"),       // 780
            ing("Trứng gà", 2.0, "quả"),          // 166
            ing("Dầu ăn", 2.0, "M"),              // 270
            ing("Gia vị: muối, tiêu", 0.0, ""),   // bỏ qua
            ing("Hành lá", 3.0, "cây"),           // 7.5
        ];
        assert_eq!(estimate_recipe(&list), Some(1220));
    }

    #[test]
    fn nhan_ra_qua_it_thi_khong_uoc_tinh() {
        let list = vec![
            ing("Thịt ba chỉ", 300.0, "g"),
            ing("Gia vị bí truyền ABC", 1.0, "gói"),
            ing("Xốt đặc biệt ABC", 2.0, "chai"),
        ];
        assert_eq!(estimate_recipe(&list), None);
    }
}
