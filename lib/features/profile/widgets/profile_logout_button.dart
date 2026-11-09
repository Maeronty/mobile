// =============================================================================
// WIDGET: NÚT ĐĂNG XUẤT (Hồ sơ)
// =============================================================================
//
// FLOW
//   Bấm nút → hiện SnackBar. App đang ở chế độ khách nên chưa đăng xuất thật.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ProfileLogoutButton extends StatelessWidget {
  const ProfileLogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
      ),
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Đăng xuất tài khoản'),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang ở chế độ trải nghiệm khách.')),
        );
      },
    );
  }
}
