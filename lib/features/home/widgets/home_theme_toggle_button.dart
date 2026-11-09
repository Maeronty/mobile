// =============================================================================
// WIDGET: NÚT ĐỔI GIAO DIỆN SÁNG / TỐI (AppBar trang chủ)
// =============================================================================
//
// FLOW
//   Bấm nút → ThemeController.toggleTheme() → MaterialApp đổi theme
//   → `Theme.of(context)` báo thay đổi → widget tự build lại với icon mới.
//
// LƯU Ý
//   Phải đọc độ sáng từ `Theme.of(context)`, KHÔNG đọc `isDarkMode` trực tiếp:
//   HomeScreen không setState khi toggle nên widget cần phụ thuộc vào Theme để
//   được build lại.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../theme/theme_controller.dart';

class HomeThemeToggleButton extends StatelessWidget {
  const HomeThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      icon: Icon(
        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: AppColors.primary,
      ),
      onPressed: ThemeController.instance.toggleTheme,
    );
  }
}
