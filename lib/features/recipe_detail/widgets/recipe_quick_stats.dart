// =============================================================================
// WIDGET: THẺ THỐNG KÊ NHANH (Chi tiết công thức)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị thời gian nấu, năng lượng và đánh giá của món.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/models/recipe.dart';
import '../../../core/theme/app_colors.dart';
import 'recipe_stat_item.dart';

class RecipeQuickStats extends StatelessWidget {
  final Recipe recipe;

  const RecipeQuickStats({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.dividerDark
              : AppColors.dividerLight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Không rõ thời gian nấu → ẩn hẳn ô này (không hiện "—").
          if (recipe.cookTimeLabel case final time?) ...[
            RecipeStatItem(
              icon: Icons.timer_outlined,
              value: time,
              label: recipe.cookTimeEstimated
                  ? 'Thời gian (ước tính)'
                  : 'Thời gian',
            ),
            Container(
              width: 1,
              height: 32,
              color: Colors.grey.withOpacity(0.2),
            ),
          ],
          // Không rõ calo → ẩn hẳn ô này. Calo ước tính là cho CẢ MÓN.
          if (recipe.caloriesLabel case final kcal?) ...[
            RecipeStatItem(
              icon: Icons.local_fire_department_outlined,
              value: kcal,
              label: recipe.caloriesEstimated ? 'Cả món (ước tính)' : 'Năng lượng',
              iconColor: AppColors.accentOrange,
            ),
            Container(width: 1, height: 32, color: Colors.grey.withOpacity(0.2)),
          ],
          RecipeStatItem(
            icon: Icons.star_rounded,
            value: recipe.totalRatings == 0
                ? "Chưa có"
                : "${recipe.averageRating} (${recipe.totalRatings})",
            label: 'Đánh giá',
            iconColor: Colors.amber,
          ),
        ],
      ),
    );
  }
}
