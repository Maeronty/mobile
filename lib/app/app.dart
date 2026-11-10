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
//   4. Màn hình gốc do AuthController quyết định (lắng nghe cùng lúc):
//        - Chưa khôi phục xong phiên → vòng xoay chờ.
//        - Đã đăng nhập hoặc chọn dùng thử → MainNavigationScreen (4 tab).
//        - Còn lại → LoginScreen.
//      Đăng nhập / đăng xuất chỉ cần đổi state trong AuthController, không
//      cần Navigator; `ValueKey` giúp xoá state cũ của app khi đổi tài khoản.
// =============================================================================

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/theme/theme_controller.dart';
import 'main_navigation_screen.dart';

class TomatoFoodTipApp extends StatelessWidget {
  const TomatoFoodTipApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.instance;
    final auth = AuthController.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([themeController, auth]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Bếp Việt - Food Tip System',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          themeAnimationDuration: Duration.zero,
          home: !auth.isReady
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : auth.canEnterApp
                  ? MainNavigationScreen(key: ValueKey(auth.user?.userId ?? 'guest'))
                  : const LoginScreen(),
        );
      },
    );
  }
}
