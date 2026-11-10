// =============================================================================
// WIDGET: KHUNG BÁO LỖI ĐĂNG NHẬP / ĐĂNG KÝ (câu lỗi trả về từ server)
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.accent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
