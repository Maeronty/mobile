// =============================================================================
// WIDGET: LOGO & TÊN ỨNG DỤNG (tiêu đề AppBar trang chủ)
// =============================================================================
//
// VAI TRÒ
//   Chỉ hiển thị logo, tên "Bếp Việt" và slogan.
//
// LƯU Ý
//   Màu slogan lấy từ `Theme.of(context)` để widget tự build lại khi đổi theme
//   (HomeScreen không gọi setState khi toggle Dark Mode).
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class HomeBrandTitle extends StatelessWidget {
  const HomeBrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.eco_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bếp Việt',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Food Tip & Smart Cooking',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
