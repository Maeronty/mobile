// =============================================================================
// APP ROOT — Cấu hình MaterialApp
// =============================================================================
//
// FLOW
//   1. main() → runApp(TomatoFoodTipApp).
//   2. TomatoFoodTipApp lắng nghe ThemeController qua ListenableBuilder.
//   3. Khi người dùng đổi Sáng/Tối → ThemeController.notifyListeners() →
//      MaterialApp build lại với `themeMode` mới (light/dark theme khai báo
//      trong core/theme/app_theme.dart).
//   4. Màn hình gốc là MainNavigationScreen (thanh điều hướng 4 tab).
// =============================================================================

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/theme/theme_controller.dart';
import 'main_navigation_screen.dart';

class TomatoFoodTipApp extends StatelessWidget {
  const TomatoFoodTipApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.instance;

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Bếp Việt - Food Tip System',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          themeAnimationDuration: Duration.zero,
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}
