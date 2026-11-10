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
//   1. Tải danh mục công thức (server, lỗi thì dùng bản có sẵn trong assets).
//   2. Khôi phục phiên đăng nhập đã ghi nhớ (nếu có).
//   3. Vẽ giao diện; AuthGate trong app.dart chọn màn đăng nhập hay vào app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    RecipeRepository.instance.load(),
    AuthController.instance.restoreSession(),
  ]);
  runApp(const TomatoFoodTipApp());
}
