# 🍲 Bếp Việt - Food Tip & Smart Cooking System

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Material 3](https://img.shields.io/badge/Material%203-757575?style=for-the-badge&logo=materialdesign&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Completed-success?style=for-the-badge)

<p align="center">
  <strong>Hệ thống gợi ý món ăn, quản lý tủ lạnh thông minh và đồng hành nấu nướng hàng ngày</strong>
  <br />
  <em>Đồ án phát triển ứng dụng di động - Trường Đại học Công nghệ TP.HCM (HUTECH)</em>
</p>

</div>

---

## 📖 1. Giới Thiệu Dự Án

**Bếp Việt - Food Tip System** là ứng dụng di động thông minh được xây dựng nhằm giải quyết câu hỏi muôn thuở: *"Hôm nay ăn gì?"* và bài toán lãng phí thực phẩm trong các hộ gia đình trẻ hiện đại. 

Ứng dụng kết hợp giữa **thuật toán đối soát nguyên liệu thông minh**, **lập kế hoạch dinh dưỡng cá nhân hoá** và **trợ lý nấu ăn rảnh tay từng bước**, mang lại trải nghiệm làm bếp đơn giản, thú vị và tiết kiệm tối đa chi phí.

---

## ✨ 2. Các Tính Năng Nổi Bật

### 🥗 2.1. Khám Phá Công Thức Ẩm Thực (Explore & Home)
- **Banner Coverflow tương tác**: Trình chiếu các món ăn đặc sản Việt Nam và quốc tế thịnh hành.
- **Phân loại danh mục đa dạng**: Món Việt truyền thống, Món Âu, Healthy / Keto, Món ăn vặt, Tráng miệng,...
- **Bộ sưu tập nấu nhanh**: Lọc các công thức hoàn thành trong vòng **dưới 25 phút** phù hợp cho người bận rộn.
- **Tìm kiếm đa năng**: Tìm nhanh theo tên món, độ khó, thời gian chế biến và mức calo.

### 🧊 2.2. "Túi Thần Kỳ" & Gợi Ý Món Ăn Theo Tủ Lạnh (Smart Fridge & Match Score)
- **Quản lý nguyên liệu sẵn có**: Thêm, xoá và cập nhật nguyên liệu đang có sẵn trong tủ lạnh gia đình.
- **Thuật toán tính điểm khớp (Match Score Algorithm)**:
  - Tự động phân tích nguyên liệu người dùng nhập đối chiếu với kho công thức.
  - Phân loại rõ ràng: **Nguyên liệu đã có sẵn** (Matched) và **Nguyên liệu cần mua thêm** (Missing).
  - Sắp xếp kết quả ưu tiên món ăn có độ tương thích cao nhất để tận dụng triệt để thực phẩm.

### 🍳 2.3. Chi Tiết Công Thức & Chế Độ Nấu Rảnh Tay (Recipe Detail & Cooking Mode)
- **Điều chỉnh khẩu phần động (Serving Scaler)**: Tự động nhân/chia định lượng từng nguyên liệu theo số lượng người ăn (1 người, 2 người, 4 người,...).
- **Phân tích dinh dưỡng chuyên sâu**: Cung cấp biểu đồ chỉ số dinh dưỡng (Calories, Protein, Carbs, Fat, Fiber).
- **Danh sách nguyên liệu tương tác (Interactive Checklist)**: Đánh dấu tick chọn các nguyên liệu đã chuẩn bị.
- **Chế độ nấu toàn màn hình (Step-by-Step Cooking Mode)**:
  - Hướng dẫn từng bước với cỡ chữ lớn, trực quan khi đặt điện thoại trên kệ bếp.
  - **Đồng hồ đếm ngược (Countdown Timer)** tích hợp cho từng bước nấu nướng kèm cảnh báo khi hoàn tất.
  - **Mô phỏng trợ lý ảo giọng nói** đồng hành và mẹo hữu ích từ đầu bếp chuyên nghiệp.

### 🥗 2.4. Cố Vấn Dinh Dưỡng & Lập Kế Hoạch Bữa Ăn (Nutrition Advisor & Meal Planner)
- **Tùy biến theo đối tượng**: Cá nhân, Cặp đôi, Gia đình (4 người), Đại gia đình (6+ người).
- **Mục tiêu sức khỏe đa dạng**:
  - *Cân bằng & Tiết kiệm*: Bữa ăn chuẩn chi phí và đủ chất.
  - *Giảm cân / Giảm mỡ*: Kiểm soát chặt chẽ lượng calories nạp vào.
  - *Tăng cơ (High Protein)*: Giàu đạm hỗ trợ tập luyện thể thao.
  - *Eat Clean*: Thanh lọc cơ thể, ưu tiên nguyên liệu tươi sạch.
- **Lập thực đơn 7 ngày**: Phân chia chi tiết Sáng - Trưa - Tối kèm mức chi phí dự tính mỗi ngày.

### ⚙️ 2.5. Cá Nhân Hoá & Giao Diện Hiện Đại
- **Hỗ trợ giao diện Sáng / Tối (Light & Dark Mode)** mượt mà, bảo vệ mắt khi nấu ăn ban đêm.
- Quản lý danh sách món ăn yêu thích, thống kê số lượt đã nấu và hồ sơ người dùng.
- Giao diện gói nâng cấp tài khoản **Bếp Việt Pro VIP**.

---

## 🏗️ 3. Cấu Trúc Thư Mục Dự Án (Project Structure)

Dự án tổ chức theo hướng **feature-first** với tôn chỉ **"1 feature = 1 thư mục, toàn bộ logic của feature nằm ở 1 file controller"**:

- `*_controller.dart` — chứa **state + logic + flow** của feature (kèm chú thích giải thích từng bước ở đầu file). Không import widget/giao diện.
- `*_screen.dart` — **chỉ giao diện**: đọc dữ liệu từ controller và gọi hành động của controller.
- `core/` — phần dùng chung giữa nhiều feature (models, dữ liệu mẫu, theme, widget tái sử dụng).

```text
mobile/
├── assets/images/                     # Hình ảnh món ăn
├── lib/
│   ├── main.dart                      # Entry point
│   ├── app/
│   │   ├── app.dart                   # MaterialApp + lắng nghe Dark Mode
│   │   └── main_navigation_screen.dart# Thanh điều hướng 4 tab (IndexedStack)
│   ├── core/                          # ── Dùng chung ──
│   │   ├── data/
│   │   │   ├── mock_data.dart         # Dữ liệu mẫu: công thức, người dùng, thực đơn
│   │   │   └── recipe_repository.dart # Kho công thức (single source of truth)
│   │   ├── models/                    # recipe.dart · user_profile.dart · meal_plan.dart
│   │   ├── theme/                     # app_colors.dart · app_theme.dart
│   │   └── widgets/                   # recipe_card.dart · difficulty_stars.dart
│   └── features/                      # ── Mỗi feature 1 thư mục ──
│       ├── home/                      # Trang chủ: banner, lọc danh mục, nấu nhanh
│       │   ├── home_controller.dart
│       │   └── home_screen.dart
│       ├── suggest/                   # Gợi ý món + thuật toán Match Score
│       │   ├── suggest_controller.dart
│       │   └── suggest_screen.dart
│       ├── kitchen_bag/               # Túi Thần Kỳ: tủ lạnh (pantry) + tab Đã Lưu
│       │   ├── pantry_controller.dart
│       │   └── kitchen_bag_screen.dart
│       ├── favorites/                 # Món yêu thích (dùng ở Card, Chi tiết, Túi Thần Kỳ)
│       │   └── favorites_controller.dart
│       ├── recipe_detail/             # Chi tiết công thức: khẩu phần động + checklist
│       │   ├── recipe_detail_controller.dart
│       │   └── recipe_detail_screen.dart
│       ├── cooking_mode/              # Nấu từng bước: chuyển bước, đồng hồ, giọng nói
│       │   ├── cooking_mode_controller.dart
│       │   └── cooking_mode_screen.dart
│       ├── nutrition/                 # Cố vấn dinh dưỡng & thực đơn 7 ngày
│       │   ├── nutrition_controller.dart
│       │   └── nutrition_advisor_screen.dart
│       ├── profile/                   # Hồ sơ, chế độ ăn, thông báo, gói Pro
│       │   ├── profile_controller.dart
│       │   ├── profile_screen.dart
│       │   └── pricing_screen.dart
│       └── theme/                     # Bật/tắt Dark Mode
│           └── theme_controller.dart
├── test/widget_test.dart
└── pubspec.yaml
```

**Luồng dữ liệu chung:** `Screen` gọi hành động trên `Controller` → controller cập nhật state và `notifyListeners()` → screen đang lắng nghe gọi `setState` để build lại.
Controller dùng chung giữa nhiều màn hình (Theme, Favorites, Pantry, Profile) là **singleton** (`XxxController.instance`); controller chỉ thuộc 1 màn hình (Home, Suggest, Recipe Detail, Cooking Mode, Nutrition) được tạo trong `initState` và huỷ trong `dispose`.

### 3.1. Luồng Xử Lý Của Từng Feature (Flow & Logic)

> Chi tiết từng bước được chú thích ngay ở đầu mỗi file `*_controller.dart`. Bảng dưới là bản tóm tắt.

| Feature | Controller | Flow chính |
| :--- | :--- | :--- |
| **Trang chủ** | `home/home_controller.dart` | Timer 4s → `nextBannerIndex` (quay vòng) → banner trượt · Chạm chip danh mục → `selectCategory` → `filteredRecipes` · `fastRecipes` = món nấu ≤ 25 phút |
| **Gợi ý thông minh** | `suggest/suggest_controller.dart` | Nạp nguyên liệu ban đầu (truyền vào → tủ lạnh → bộ mặc định) → chọn chế độ *Theo tủ lạnh* / *Theo tên món* → `results()` → sắp xếp theo độ khớp / đánh giá / thời gian / calo |
| **Tủ lạnh (Pantry)** | `kitchen_bag/pantry_controller.dart` | `addIngredient` (trim, bỏ rỗng & trùng) · `removeIngredient` · `clear` → nút *"Gợi ý món từ N nguyên liệu"* mở màn Gợi ý |
| **Yêu thích** | `favorites/favorites_controller.dart` | Lưu `Set<int>` id món → `toggleFavorite` thêm/bỏ → `favoriteRecipes` cho tab *Đã Lưu* |
| **Chi tiết công thức** | `recipe_detail/recipe_detail_controller.dart` | `scaleFactor = khẩu phần chọn / khẩu phần gốc` → nhân cho nguyên liệu & dinh dưỡng · tick nguyên liệu đã chuẩn bị |
| **Chế độ nấu ăn** | `cooking_mode/cooking_mode_controller.dart` | Mỗi bước nạp timer = `estimatedMinutes` (mặc định 3') · Play/Pause đếm ngược 1s → về 0 thì báo *Hết giờ* · `nextStep` ở bước cuối → chúc mừng hoàn tất |
| **Dinh dưỡng** | `nutrition/nutrition_controller.dart` | Chọn đối tượng + mục tiêu → `generatePlan()` (loading 600ms) → thực đơn 7 ngày → chọn ngày xem chi tiết bữa ăn |
| **Hồ sơ** | `profile/profile_controller.dart` | Giữ `currentUser`, chế độ ăn, bật/tắt thông báo |
| **Giao diện Sáng/Tối** | `theme/theme_controller.dart` | `toggleTheme()` → `app/app.dart` lắng nghe → MaterialApp đổi `themeMode` |

#### Thuật toán Match Score (Gợi ý theo tủ lạnh)

```text
Với mỗi công thức:
  1. Duyệt từng nguyên liệu của công thức
  2. "Đã có" nếu tên nguyên liệu CHỨA hoặc ĐƯỢC CHỨA trong nguyên liệu người dùng nhập
     (không phân biệt hoa/thường — VD: "bò" khớp "Thịt bò")
  3. Chia vào matched (đã có) / missing (cần mua thêm)
  4. score = matched / tổng số nguyên liệu   (0.0 → 1.0)
  5. Bỏ món không khớp nguyên liệu nào
Sắp xếp giảm dần theo score → món tận dụng tủ lạnh tốt nhất đứng đầu.
```

#### Luồng dữ liệu giữa UI và Controller

```text
 Người dùng thao tác ─▶ Screen gọi hàm của Controller
                              │
                              ▼
                 Controller cập nhật state + notifyListeners()
                              │
                              ▼
          Screen (đã addListener) gọi setState() ─▶ build lại giao diện
```

> **Lưu ý:** `NutritionAdvisorScreen` đã hoàn thiện nhưng **chưa được gắn vào thanh điều hướng** (`lib/app/main_navigation_screen.dart`).

### 3.2. Quy Ước Khi Thêm Feature Mới

1. Tạo thư mục `lib/features/<ten_feature>/`.
2. Viết **toàn bộ logic** vào `<ten_feature>_controller.dart` (kế thừa `ChangeNotifier`), mở đầu bằng khối chú thích: *Vai trò → Flow từng bước → Lưu ý*.
3. Viết giao diện vào `<ten_feature>_screen.dart`: chỉ đọc state và gọi hàm của controller, **không** viết logic nghiệp vụ trong widget.
4. Nếu state dùng chung nhiều màn hình → controller dạng singleton (`static final instance`); nếu chỉ thuộc 1 màn hình → tạo trong `initState`, huỷ trong `dispose`.
5. Model / widget / dữ liệu dùng chung nhiều feature đặt trong `lib/core/`.

---

## 🛠️ 4. Công Nghệ & Thư Viện Sử Dụng (Tech Stack)

| Thành phần | Công nghệ / Gói thư viện | Mô tả |
| :--- | :--- | :--- |
| **Framework** | [Flutter 3.x](https://flutter.dev/) | Cross-platform UI toolkit |
| **Language** | [Dart 3.x](https://dart.dev/) | Ngôn ngữ lập trình hiện đại, type-safe |
| **Design System** | [Material Design 3](https://m3.material.io/) | Thiết kế hiện đại, hỗ trợ Dynamic Color & Dark Mode |
| **State Management** | `ChangeNotifier` (1 controller / feature) | Mỗi feature có controller riêng, UI lắng nghe và build lại khi state đổi |
| **Formatting & Time** | `intl: ^0.20.3` | Hỗ trợ định dạng số, ngày giờ và tiền tệ Việt Nam |
| **Icons** | `cupertino_icons: ^1.0.8` & Material Icons | Bộ icon đa nền tảng sắc nét |
| **Linter** | `flutter_lints: ^6.0.0` | Đảm bảo tiêu chuẩn code sạch (Clean Code Guidelines) |

---

## 🚀 5. Hướng Dẫn Cài Đặt & Chạy Ứng Dụng (Getting Started)

### Yêu Cầu Môi Trường
- **Flutter SDK**: Phiên bản `>= 3.13.4`
- **Dart SDK**: Phiên bản `>= 3.0.0`
- **IDE**: Android Studio / Visual Studio Code (đã cài Flutter & Dart extension)
- Thiết bị chạy thử nghiệm: Máy ảo (Android Emulator / iOS Simulator) hoặc điện thoại thật bật chế độ Developer Mode / USB Debugging.

### Các Bước Thực Hiện

1. **Clone repository về máy**:
   ```bash
   git clone https://github.com/Maeronty/mobile.git
   cd mobile
   ```

2. **Cài đặt các thư viện phụ thuộc (Dependencies)**:
   ```bash
   flutter pub get
   ```

3. **Kiểm tra tình trạng môi trường phát triển**:
   ```bash
   flutter doctor
   ```

4. **Khởi chạy ứng dụng**:
   - Chạy trên thiết bị kết nối mặc định:
     ```bash
     flutter run
     ```
   - Chạy ở chế độ Release:
     ```bash
     flutter run --release
     ```

5. **Đóng gói ứng dụng (Build)**:
   - **Android APK**:
     ```bash
     flutter build apk --split-per-abi
     ```
   - **Android App Bundle (Google Play)**:
     ```bash
     flutter build appbundle
     ```
   - **iOS (Yêu cầu macOS & Xcode)**:
     ```bash
     flutter build ipa
     ```

---

## 🧪 6. Kiểm Thử (Testing)

Chạy bộ kiểm thử tự động của dự án:
```bash
flutter test
```

---

## 🎯 7. Định Hướng Phát Triển Tương Lai (Roadmap)

- [ ] **AI Vision - Quét ảnh tủ lạnh**: Tích hợp Google Gemini Multimodal / YOLOv8 để tự động nhận diện nguyên liệu thông qua camera điện thoại.
- [ ] **Kết nối Backend RESTful API**: Tích hợp NodeJS / Spring Boot / Firebase để đồng bộ dữ liệu tài khoản và lưu trữ đám mây.
- [ ] **Voice Recognition tương tác 2 chiều**: Điều khiển lật trang công thức tiếp theo bằng khẩu lệnh ("Bước tiếp theo", "Hẹn giờ 5 phút") giúp tay không chạm màn hình khi đang dính dầu mỡ.
- [ ] **Liên kết siêu thị & Mua sắm (E-Commerce integration)**: Tự động gom các nguyên liệu còn thiếu vào giỏ hàng và liên kết giao hàng tận nơi.

---

## 👨‍💻 8. Thông Tin Đồ Án (Project Information)

- **Trường**: Trường Đại học Công nghệ TP.HCM (HUTECH)
- **Khoa**: Công nghệ Thông tin
- **Môn học**: Đồ án chuyên ngành / Đồ án phát triển ứng dụng di động
- **Ứng dụng**: Bếp Việt - Food Tip System (Mobile Client)

---

## 📄 9. Bản Quyền (License)

Dự án được phân phối dưới giấy phép [MIT License](LICENSE). Dự án phục vụ mục đích nghiên cứu, học tập tại Đại học HUTECH.

<div align="center">
  <sub>Made with ❤️ by HUTECH Engineering Students</sub>
</div>
