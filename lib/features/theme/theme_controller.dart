// =============================================================================
// FEATURE: GIAO DIỆN SÁNG / TỐI (Light & Dark Mode)
// =============================================================================
//
// VAI TRÒ
//   Lưu trạng thái giao diện hiện tại và cho phép bật/tắt Dark Mode.
//
// FLOW
//   1. App khởi động → `isDarkMode = false` (giao diện sáng).
//   2. Người dùng bấm nút mặt trăng/mặt trời (Home, Profile) hoặc công tắc
//      "Giao diện tối" (Profile) → gọi `toggleTheme()`.
//   3. `toggleTheme()` đảo giá trị và `notifyListeners()`.
//   4. `TomatoFoodTipApp` (lib/app/app.dart) đang lắng nghe controller này qua
//      ListenableBuilder → build lại MaterialApp với `themeMode` mới.
//
// LƯU Ý
//   - Trạng thái chỉ nằm trong bộ nhớ, tắt app sẽ quay về giao diện sáng.
// =============================================================================

import 'package:flutter/foundation.dart';

class ThemeController extends ChangeNotifier {
  /// Singleton: chỉ có 1 trạng thái giao diện cho toàn app.
  static final ThemeController instance = ThemeController._();

  ThemeController._();

  bool _isDarkMode = false;

  /// `true` nếu đang dùng giao diện tối.
  bool get isDarkMode => _isDarkMode;

  /// Chuyển đổi Sáng ⇄ Tối và báo cho UI build lại.
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}
