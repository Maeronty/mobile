// =============================================================================
// WIDGET: THANH "BẮT ĐẦU NẤU" DƯỚI ĐÁY (Chi tiết công thức)
// =============================================================================
//
// FLOW
//   Bấm nút → `onPressed` → RecipeDetailScreen mở CookingModeScreen.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class RecipeStartCookingBar extends StatelessWidget {
  final VoidCallback onPressed;

  const RecipeStartCookingBar({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.dividerDark
                : AppColors.dividerLight,
          ),
        ),
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppColors.primary,
          ),
          icon: const Icon(Icons.play_circle_filled_rounded, size: 24),
          label: const Text(
            'Bắt đầu chế độ nấu ăn (Cooking Mode)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
