// =============================================================================
// WIDGET: TIÊU ĐỀ NGUYÊN LIỆU & BỘ CHỈNH KHẨU PHẦN (Chi tiết công thức)
// =============================================================================
//
// FLOW
//   Bấm [−]/[+] → `onDecrease`/`onIncrease` → RecipeDetailController đổi khẩu
//   phần → định lượng và dinh dưỡng được tính lại.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class RecipeIngredientsHeader extends StatelessWidget {
  final int totalCount;
  final int checkedCount;
  final int servings;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const RecipeIngredientsHeader({
    super.key,
    required this.totalCount,
    required this.checkedCount,
    required this.servings,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nguyên liệu cần chuẩn bị',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '$totalCount nguyên liệu ($checkedCount/$totalCount đã chuẩn bị)',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textMutedDark
                    : AppColors.textMutedLight,
              ),
            ),
          ],
        ),
        // Scaler
        Container(
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16, color: AppColors.primaryDark),
                onPressed: onDecrease,
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '$servings phần',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primaryDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16, color: AppColors.primaryDark),
                onPressed: onIncrease,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
