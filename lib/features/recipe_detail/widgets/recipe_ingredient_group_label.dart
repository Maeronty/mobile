// =============================================================================
// WIDGET: TIÊU ĐỀ NHÓM NGUYÊN LIỆU (Chi tiết công thức)
// =============================================================================
//
// FLOW
//   RecipeDetailScreen chèn widget này trước nguyên liệu đầu tiên của mỗi nhóm
//   phụ ("Gia vị", "Ăn kèm", "Dụng cụ"...) — nhóm do `normalizeIngredients`
//   tách từ dòng "Gia vị: a, b, c" của dữ liệu gốc.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class RecipeIngredientGroupLabel extends StatelessWidget {
  final String label;

  const RecipeIngredientGroupLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
