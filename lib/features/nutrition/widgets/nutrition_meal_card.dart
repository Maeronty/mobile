// =============================================================================
// WIDGET: THẺ MỘT BỮA ĂN (Dinh dưỡng)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị ảnh món, loại bữa, calo, tên món, đạm/carb/béo và mẹo.
//
// LƯU Ý
//   Ảnh lỗi → hiện nền xám thay vì báo lỗi.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/theme/app_colors.dart';

class NutritionMealCard extends StatelessWidget {
  final MealItem meal;

  const NutritionMealCard({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dish Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: Image.network(
                ApiClient.imageUrl(meal.imageAsset),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        meal.mealType,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '${meal.calories} kcal',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentOrange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  meal.dishName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Đạm: ${meal.proteinGrams.toInt()}g', style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 8),
                    Text('Carb: ${meal.carbsGrams.toInt()}g', style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 8),
                    Text('Béo: ${meal.fatGrams.toInt()}g', style: const TextStyle(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  meal.tip,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
