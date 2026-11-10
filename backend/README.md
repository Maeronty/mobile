# Food Tip System - Backend Giai đoạn 1 (Rust)

Backend dịch vụ sản xuất (Production Service) được viết bằng **Rust**, cung cấp toàn bộ các API cốt lõi cho ứng dụng di động Flutter GreenFood/Food Tip. Hệ thống sử dụng cơ sở dữ liệu **SQLite độc lập**, tự động migrate và seed dữ liệu khi khởi động, đối chiếu và tương thích 100% với hợp đồng API của client Flutter và backend tham chiếu .NET 8.

---

## 🛠 Công nghệ & Thư viện (Tech Stack)

Hệ thống được xây dựng theo kiến trúc phân tầng (Layered Clean Architecture):
* **Web Framework:** [`axum`](https://crates.io/crates/axum) (v0.7) + [`tokio`](https://crates.io/crates/tokio) (v1 async runtime).
* **Database & ORM:** [`sqlx`](https://crates.io/crates/sqlx) (v0.8) với SQLite (WAL mode, busy timeout, tự động chạy migration `sqlx::migrate!()`).
* **Mã hóa & Bảo mật:**
  * Băm mật khẩu: [`argon2`](https://crates.io/crates/argon2) (chuẩn bảo mật hiện đại) kèm hỗ trợ tương thích ngược [`bcrypt`](https://crates.io/crates/bcrypt) cho tài khoản cũ.
  * Token xác thực: [`jsonwebtoken`](https://crates.io/crates/jsonwebtoken) (HMAC-SHA256).
* **Serialization:** [`serde`](https://crates.io/crates/serde) + [`serde_json`](https://crates.io/crates/serde_json) (chuẩn camelCase tương thích Flutter và .NET).
* **HTTP & CORS:** [`tower-http`](https://crates.io/crates/tower-http) (hỗ trợ CORS cho Flutter Web, Desktop và Mobile).
* **Logging & Tracing:** [`tracing`](https://crates.io/crates/tracing) + [`tracing-subscriber`](https://crates.io/crates/tracing-subscriber).

> Chi tiết phân tích và đánh giá an toàn cho 15 crate được ghi tại [CRATE_EVALUATION.md](CRATE_EVALUATION.md).

---

## 🚀 Hướng dẫn khởi chạy

### 1. Yêu cầu môi trường
* Rust toolchain (Rust 1.80+ và Cargo).
* Không cần cài đặt server database bên ngoài (SQLite tự khởi tạo file db cục bộ).

### 2. Chạy ứng dụng
Mở terminal trong thư mục `backend`:
```bash
# Thiết lập đường dẫn cargo nếu cần (Windows)
$env:PATH = "$env:USERPROFILE\.cargo\bin;" + $env:PATH

# Chạy backend ở chế độ phát triển (port mặc định: 8787)
cargo run
```

Khi chạy lần đầu, backend sẽ tự động:
1. Tạo file SQLite database (`sqlite://food_tip.db?mode=rwc`).
2. Kích hoạt chế độ WAL (`PRAGMA journal_mode = WAL;`) để tối ưu hiệu năng đọc/ghi đồng thời.
3. Chạy các tệp migrations trong `migrations/` để tạo các bảng `users`, `recipes`, `recipe_nutrition`, `recipe_ingredients`, `recipe_instructions`, `user_favorites`, `pantry_items`.
4. Nạp sẵn danh mục công thức mẫu vào database từ `assets/spoonacular.json`.
5. Lắng nghe tại `http://0.0.0.0:8787`.

### 3. Cấu hình biến môi trường
Sao chép `.env.example` thành `.env` rồi điền giá trị (`.env` đã nằm trong `.gitignore`).
Các biến chính:
```env
PORT=8787
DATABASE_URL=sqlite://food_tip.db?mode=rwc
JWT_SECRET=<chuỗi ngẫu nhiên dài>
JWT_EXPIRATION_HOURS=2
# AI (không bắt buộc; thiếu thì /api/Ai/* trả 503)
GEMINI_API_KEYS=key1,key2
GEMINI_MODEL=gemini-3.5-flash
SPOONACULAR_API_KEY=...
```

---

## 📱 Kết nối với Flutter Mobile Client

Trong ứng dụng Flutter (thư mục gốc của repo):
* **Chạy trên Windows / macOS / Web / Thiết bị iOS thật:**
  Backend trỏ về: `http://127.0.0.1:8787`
* **Chạy trên Android Emulator:**
  Backend trỏ về: `http://10.0.2.2:8787` (địa chỉ máy host trong mạng giả lập Android).

App tự chọn địa chỉ trên (xem `lib/core/data/api_client.dart`). Muốn trỏ tới máy khác
(VD: điện thoại thật trong cùng mạng LAN):
```bash
flutter run --dart-define=FOOD_API_URL=http://<ip-may-tinh>:8787
```

---

## 📡 Danh sách API Endpoints (Giai đoạn 1)

### 1. Xác thực & Hồ sơ (Auth & User Profile - R1)
| Phương thức | Đường dẫn API | Xác thực | Mô tả |
| :--- | :--- | :---: | :--- |
| `POST` | `/api/Account/register` | Không | Đăng ký tài khoản mới (`username`, `email`, `password`, `displayName`). |
| `POST` | `/api/Account/login` | Không | Đăng nhập bằng username/email + mật khẩu, trả về JWT token. |
| `GET` | `/api/Account/profile` | **Bearer JWT** | Lấy thông tin hồ sơ của tài khoản đang đăng nhập. |
| `PUT` | `/api/Account/update-profile` | **Bearer JWT** | Cập nhật thông tin cá nhân (`displayName`, `bio`, `dietPreference`). |
| `POST` | `/api/Account/change-password` | **Bearer JWT** | Đổi mật khẩu tài khoản (`oldPassword`, `newPassword`). |
| `POST` | `/api/Account/upgrade-to-vip` | **Bearer JWT** | Nâng cấp tài khoản VIP. |

*(Tất cả endpoint đều hỗ trợ alias chữ thường như `/api/account/...` hoặc `/api/auth/...`)*.

### 2. Danh mục món ăn & Tìm kiếm (Recipe Catalog & Search - R2)
| Phương thức | Đường dẫn API | Xác thực | Mô tả |
| :--- | :--- | :---: | :--- |
| `GET` | `/catalog` (hoặc `/api/Recipes/catalog`) | Không | Cung cấp danh mục món ăn chuẩn định dạng Spoonacular cho Flutter client. |
| `GET` | `/api/Recipes` | Tùy chọn JWT | Lấy danh sách tóm tắt món ăn (có cờ `isFavorited` động theo user). |
| `GET` | `/api/Recipes/{id}` | Tùy chọn JWT | Lấy chi tiết công thức (dinh dưỡng, nguyên liệu, các bước làm). |
| `GET` | `/api/Recipes/search?term={query}` | Tùy chọn JWT | Tìm kiếm công thức theo tên món, danh mục hoặc tag. |
| `GET` | `/api/Recipes/search-by-ingredients?ingredients=a,b,c` | Tùy chọn JWT | Thuật toán chấm điểm Match Score theo nguyên liệu. |
| `POST` | `/suggest` | Không | Gợi ý món ăn từ danh sách nguyên liệu (`{"ingredients": [...]}`). |
| `GET` | `/api/Recipes/ingredients` | Không | Lấy danh sách từ vựng nguyên liệu trong database. |
| `GET` | `/api/Recipes/stats` | Không | Thống kê số lượng món ăn và người dùng. |

### 3. Món ăn yêu thích (Favorites System - R3)
| Phương thức | Đường dẫn API | Xác thực | Mô tả |
| :--- | :--- | :---: | :--- |
| `POST` | `/api/Recipes/{id}/favorite` | **Bearer JWT** | Thả tim / bỏ thả tim (xử lý transaction nguyên tử chống race condition). |
| `GET` | `/api/Recipes/favorites` | **Bearer JWT** | Lấy danh sách các món ăn người dùng đã lưu. |
| `POST` | `/api/Recipes/sync-favorites` | **Bearer JWT** | Đồng bộ danh sách id yêu thích từ chế độ offline lên server. |

### 4. Tủ lạnh / Túi nguyên liệu (Pantry / Kitchen Bag - R4)
| Phương thức | Đường dẫn API | Xác thực | Mô tả |
| :--- | :--- | :---: | :--- |
| `GET` | `/api/pantry` | **Bearer JWT** | Lấy danh sách nguyên liệu người dùng đang có trong tủ lạnh. |
| `POST` | `/api/pantry` | **Bearer JWT** | Thêm nguyên liệu vào tủ lạnh (hỗ trợ cả dạng object lẫn text linh hoạt). |
| `PUT` | `/api/pantry/{id}` | **Bearer JWT** | Sửa thông tin nguyên liệu (số lượng, đơn vị tính). |
| `DELETE` | `/api/pantry/{id}` | **Bearer JWT** | Xóa một nguyên liệu khỏi tủ. |
| `DELETE` | `/api/pantry` | **Bearer JWT** | Dọn sạch toàn bộ tủ lạnh (hoặc xóa theo `?name=...`). |
| `GET` | `/api/pantry/suggest` | **Bearer JWT** | Tự động lấy nguyên liệu trong tủ của user và gợi ý món nấu được. |

*(Hỗ trợ cả alias `/api/kitchen-bag` và `/api/kitchenbag`)*.

### 5. Gợi ý bằng AI (Gemini + Spoonacular)
| Phương thức | Đường dẫn API | Xác thực | Mô tả |
| :--- | :--- | :---: | :--- |
| `POST` | `/api/Ai/recognize` | **Bearer JWT** | Gửi `{"mime": "image/jpeg", "data": "<base64>"}` (ảnh ≤ 3 MB), Gemini trả `["Cà chua", ...]`. |
| `POST` | `/api/Ai/suggest` | **Bearer JWT** | Gửi `{"ingredients": [...]}`: Gemini dịch → Spoonacular tìm món → Gemini xếp hạng và dịch; trả `[{id, title, reason, used, missing}]`. |

* Logic nằm trong `src/services/ai_service.rs` (chuyển từ server Node `server/food.mjs` trước đây).
* Nhiều key Gemini (`GEMINI_API_KEYS`): key bị 429 được tạm bỏ qua theo `Retry-After` (mặc định 60 giây) và chuyển sang key kế tiếp.
* Gói miễn phí của Gemini chỉ khoảng 20 request/ngày: mỗi lần gợi ý món tốn 2 request, nhận diện ảnh tốn 1.
* Kết quả chỉ giữ món có id trong kết quả Spoonacular, nên AI không bịa được món.

---

## 🧪 Kiểm thử tự động (Testing)

Dự án có bộ kiểm thử tự động toàn diện kiểm chứng cả chức năng, bảo mật và khả năng chịu tải:
```bash
# Chạy toàn bộ 122 bài kiểm thử (100% pass)
cargo test

# Kiểm tra mã nguồn với linter nghiêm ngặt
cargo clippy -- -D warnings

# Chạy riêng kịch bản kiểm thử toàn trình E2E
cargo test --test e2e_tests
```

**Các nhóm kiểm thử bao gồm:**
* `e2e_tests.rs`: Kịch bản vòng đời người dùng trọn vẹn (Đăng ký ➔ Đăng nhập ➔ Khám phá catalog ➔ Quản lý tủ lạnh ➔ Gợi ý món ➔ Thả tim ➔ Đồng bộ offline ➔ Đổi mật khẩu).
* `auth_tests.rs` & `adversarial_auth_tests.rs`: Kiểm thử xác thực, mật khẩu yếu, chống SQL Injection, kiểm tra giả mạo chữ ký JWT (`adversarial_jwt_challenge.rs`).
* `recipe_tests.rs`, `adversarial_recipe_search_tests.rs`, `adversarial_recipe_ingredient_tests.rs`: Kiểm thử tra cứu, phân tách từ ngữ nguyên liệu tiếng Việt/Anh, chống SQL Injection trên chuỗi tìm kiếm.
* `favorite_tests.rs`, `adversarial_favorite_concurrency_tests.rs`: Kiểm thử 64 tác vụ đồng thời thả tim liên tục đảm bảo tính toàn vẹn dữ liệu.
* `pantry_tests.rs`: Kiểm thử các thao tác CRUD và cách ly dữ liệu giữa các người dùng (multi-tenant isolation).
