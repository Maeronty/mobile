// =============================================================================
// ENTRY POINT — Bếp Việt (Food Tip & Smart Cooking)
// =============================================================================
//
// Cấu trúc thư mục (feature-first, mỗi feature = 1 thư mục, logic ở 1 file):
//   lib/
//   ├── main.dart                  ← file này: khởi động app
//   ├── app/                       ← vỏ ứng dụng: MaterialApp + thanh điều hướng
//   ├── core/                      ← dùng chung: models, data, theme, widgets
//   └── features/<tên_feature>/
//       ├── <feature>_controller.dart   ← TOÀN BỘ logic + flow của feature
//       └── <feature>_screen.dart       ← chỉ giao diện
// =============================================================================

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/data/recipe_repository.dart';
import 'features/auth/auth_controller.dart';

// FLOW KHỞI ĐỘNG
//   1. Khôi phục phiên đăng nhập đã ghi nhớ (nếu có) — nhanh, chỉ 1 request nhỏ.
//   2. Vẽ giao diện ngay; AuthGate trong app.dart chọn màn đăng nhập hay vào app.
//      Home tự tải từng trang món (không cần danh mục đầy đủ).
//   3. Danh mục đầy đủ (cho Gợi ý / Surprise / Tủ lạnh / Yêu thích) tải NGẦM,
//      không chặn việc mở app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthController.instance.restoreSession();
  RecipeRepository.instance.ensureLoaded();
  runApp(const TomatoFoodTipApp());
}
