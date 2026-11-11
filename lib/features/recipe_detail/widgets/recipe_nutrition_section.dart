// =============================================================================
// WIDGET: KHU VỰC GIÁ TRỊ DINH DƯỠNG (Chi tiết công thức)
// =============================================================================
//
// FLOW
//   Chỉ món có dữ liệu dinh dưỡng THẬT mới hiện đạm/tinh bột/béo; món chỉ có
//   calo ước tính (món Việt) → câu "Chưa có dữ liệu dinh dưỡng", calo ước tính
//   cả món đã hiện ở ô "Năng lượng" phía trên.
//
// LƯU Ý
//   Món không có dữ liệu chất xơ → hiển thị "—" (không bịa số).
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/models/recipe.dart';
import '../../../core/theme/app_colors.dart';
import 'recipe_nutrition_badge.dart';

class RecipeNutritionSection extends StatelessWidget {
  final NutritionInfo nutrition;
  final String Function(double grams) formatGrams;

  const RecipeNutritionSection({
    super.key,
    required this.nutrition,
    required this.formatGrams,
  });

  @override
  Widget build(BuildContext context) {
    if (nutrition.calories <= 0) {
      return Text(
        'Chưa có dữ liệu dinh dưỡng cho món này.',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Giá trị dinh dưỡng (mỗi khẩu phần)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            RecipeNutritionBadge(
              title: 'Đạm',
              value: '${formatGrams(nutrition.proteinGrams)}g',
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            RecipeNutritionBadge(
              title: 'Tinh bột',
              value: '${formatGrams(nutrition.carbsGrams)}g',
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            RecipeNutritionBadge(
              title: 'Chất béo',
              value: '${formatGrams(nutrition.fatGrams)}g',
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            RecipeNutritionBadge(
              title: 'Chất xơ',
              value: nutrition.fiberGrams == null
                  ? '—'
                  : '${formatGrams(nutrition.fiberGrams!)}g',
              color: Colors.green,
            ),
          ],
        ),
      ],
    );
  }
}
