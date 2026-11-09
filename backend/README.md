# Bếp Việt Backend

REST API cho app Bếp Việt, viết bằng FastAPI và SQLite. Dữ liệu lưu trong một file
`data/bepviet.db`, không cần cài database server.

## Chạy lần đầu

Chạy các lệnh sau trong thư mục `backend/` (PowerShell):

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
Copy-Item .env.example .env
```

Mở `.env`, điền `JWT_SECRET` bằng chuỗi tạo từ lệnh sau:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Chạy server:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --port 5193
```

- Swagger để thử API: http://localhost:5193/swagger/index.html
- Android emulator gọi qua `http://10.0.2.2:5193`.
- Điện thoại thật: chạy thêm `--host 0.0.0.0` và gọi qua IP LAN của máy tính.

Lần chạy đầu sẽ tự tạo bảng và nạp 10 công thức từ `app/data/seed_recipes.json`.

## Bật AI (Google AI Studio / Gemini)

Lấy API key miễn phí từ [Google AI Studio](https://aistudio.google.com/), dán vào `backend/.env` rồi khởi động lại server:

```env
GEMINI_API_KEY=AIzaSy...
AI_MODEL=gemini-3.5-flash
```

*(Hệ thống cũng hỗ trợ `GOOGLE_API_KEY` hoặc `ANTHROPIC_API_KEY` nếu bạn muốn dùng Claude).*

| Điều kiện | Kết quả của `generate-plan` |
|---|---|
| Có key và đã đăng nhập | AI tạo thực đơn, `source: "ai"` |
| AI lỗi, hết giờ hoặc từ chối | Tạo theo quy tắc, `source: "rule_based"`, `notice` ghi lý do |
| Chưa có key, hoặc là khách | Tạo theo quy tắc, `source: "rule_based"` |
| Thực đơn chay mà không dùng được AI | Lỗi 503, vì dữ liệu mẫu chưa có món chay |

`GET /health` trả về `aiEnabled` để kiểm tra key đã được nạp chưa. **Không commit file
`.env`**; file này đã nằm trong `.gitignore`.

## API

Tất cả nằm dưới `/api`. 🔒 là cần header `Authorization: Bearer <token>`.
Lỗi luôn có dạng `{"message": "..."}`.

| Method | Đường dẫn | Mô tả |
|---|---|---|
| POST | `/Account/register` | Đăng ký, trả về thông tin và token |
| POST | `/Account/login` | Đăng nhập bằng username hoặc email |
| GET | `/Recipes` | Tất cả công thức |
| GET | `/Recipes/{id}` | Chi tiết công thức |
| GET | `/Recipes/search?term=` | Tìm theo tên, danh mục, tag |
| GET | `/Recipes/search-by-ingredients?ingredients=a,b` | Gợi ý theo nguyên liệu, kèm điểm khớp |
| GET | `/Recipes/ingredients` | Tên tất cả nguyên liệu |
| GET 🔒 | `/Recipes/favorites` | Id các món yêu thích |
| POST 🔒 | `/Recipes/{id}/favorite` | Bật/tắt yêu thích |
| GET 🔒 | `/Pantry` | Tủ lạnh của người dùng |
| POST 🔒 | `/Pantry` | Thêm nguyên liệu |
| DELETE 🔒 | `/Pantry/{name}` | Xoá một nguyên liệu |
| DELETE 🔒 | `/Pantry` | Dọn sạch tủ |
| GET 🔒 | `/Profile` | Xem hồ sơ |
| PUT 🔒 | `/Profile` | Sửa tên, giới thiệu, ảnh, chế độ ăn, thông báo |
| POST | `/NutritionAdvisor/generate-plan` | Tạo thực đơn 1–7 ngày |

Route và tên trường khớp với code gọi API trên nhánh `backend` của repo.

## Cấu trúc

```
app/
├── main.py              Khởi động, định dạng lỗi, gắn các feature
├── core/                Cấu hình, database, bảng, JWT, dữ liệu seed
├── data/                File seed công thức
└── features/<feature>/
    ├── router.py        Chỉ nhận request
    ├── service.py       Logic và flow của feature
    └── schemas.py       Dạng dữ liệu vào/ra
```

## Test

```powershell
.\.venv\Scripts\python.exe -m pytest
```

Test dùng database tạm và server AI giả, nên không tốn tiền và không đụng dữ liệu thật.

## Trước khi đưa lên môi trường thật

- Chưa giới hạn tần suất: người dùng đã đăng nhập có thể gọi AI liên tục và tốn tiền
  API, đăng nhập cũng chưa chặn dò mật khẩu.
- SQLite hợp với một server và lượng ghi vừa phải. Nhiều server cùng lúc cần đổi
  sang database khác.
- Chưa có migration: đổi cấu trúc bảng trên dữ liệu thật cần thêm công cụ như Alembic.
- Cần chạy sau HTTPS để token không bị lộ trên đường truyền.
