// =============================================================================
// WIDGET: CHIP CHỌN MỘT GIÁ TRỊ (Surprise Me)
// =============================================================================
//
// VAI TRÒ
//   Dùng cho bộ lọc Thời gian và Độ khó.
//
// FLOW
//   Chạm chip → `onTap`. Chạm lại chip đang chọn sẽ bỏ chọn (logic ở controller).
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SurpriseFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SurpriseFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
        ),
      ),
      onSelected: (_) => onTap(),
    );
  }
}
