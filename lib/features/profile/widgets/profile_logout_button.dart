// =============================================================================
// WIDGET: NÚT ĐĂNG XUẤT / ĐĂNG NHẬP (Hồ sơ)
// =============================================================================
//
// FLOW
//   - Đã đăng nhập → "Đăng xuất" → `AuthController.logout()`.
//   - Khách → "Đăng nhập / Đăng ký" → `logout()` cũng thoát chế độ khách.
//   Cả hai trường hợp AuthGate (app.dart) tự đưa về LoginScreen.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/auth_controller.dart';

class ProfileLogoutButton extends StatelessWidget {
  const ProfileLogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.instance;
    final color = auth.isLoggedIn ? AppColors.accent : AppColors.primary;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        foregroundColor: color,
        side: BorderSide(color: color),
      ),
      icon: Icon(auth.isLoggedIn ? Icons.logout_rounded : Icons.login_rounded),
      label: Text(auth.isLoggedIn ? 'Đăng xuất tài khoản' : 'Đăng nhập / Đăng ký'),
      onPressed: auth.logout,
    );
  }
}
