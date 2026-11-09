// =============================================================================
// WIDGET: GIAO DIỆN KẾT QUẢ (Surprise Me — trạng thái Result)
// =============================================================================
//
// FLOW
//   - Hiển thị thẻ món ăn; "Xem công thức" và "Nấu ngay" chuyển lên màn hình cha
//     để điều hướng.
//   - "Đổi món khác" → controller.reroll → đầu bếp nấu lại.
//   - "Tùy chỉnh lại bộ lọc" → controller.backToSetup.
//
// LƯU Ý
//   Nếu chưa có món (`currentRecipe == null`) → chỉ hiện nút quay lại bộ lọc.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/models/recipe.dart';
import '../../../core/theme/app_colors.dart';
import '../surprise_me_controller.dart';
import 'surprise_hero_card.dart';

class SurpriseResultView extends StatelessWidget {
  final SurpriseMeController controller;
  final ValueChanged<Recipe> onViewRecipe;
  final ValueChanged<Recipe> onCookNow;

  const SurpriseResultView({
    super.key,
    required this.controller,
    required this.onViewRecipe,
    required this.onCookNow,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = controller.currentRecipe;
    if (recipe == null) {
      return Center(
        child: ElevatedButton(
          onPressed: controller.backToSetup,
          child: const Text('Quay lại chọn tiêu chí'),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Banner chúc mừng
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✨', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Text(
                  'MÓN NGON BÍ MẬT DÀNH CHO BẠN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          SurpriseHeroCard(
            recipe: recipe,
            onViewRecipe: () => onViewRecipe(recipe),
            onCookNow: () => onCookNow(recipe),
          ),

          const SizedBox(height: 20),

          // Nút Đổi món khác (Đầu bếp xào nấu lại 4s)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: controller.reroll,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text(
                'Đổi món khác (Xào nấu lại)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Nút quay lại chỉnh bộ lọc
          TextButton.icon(
            onPressed: controller.backToSetup,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Tùy chỉnh lại bộ lọc'),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
