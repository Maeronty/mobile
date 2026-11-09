// =============================================================================
// WIDGET: MỘT Ô THỐNG KÊ NHANH (Chi tiết công thức)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị icon, giá trị và nhãn; `iconColor` mặc định là màu chính.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class RecipeStatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  const RecipeStatItem({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textMutedDark
                : AppColors.textMutedLight,
          ),
        ),
      ],
    );
  }
}
