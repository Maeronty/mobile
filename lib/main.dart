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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TomatoFoodTipApp());
}
