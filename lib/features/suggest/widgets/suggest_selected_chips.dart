// =============================================================================
// WIDGET: CHIP NGUYÊN LIỆU ĐANG CHỌN (màn Gợi ý)
// =============================================================================
//
// FLOW
//   Bấm × trên chip → `onRemove(ingredient)` → kết quả tính lại.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SuggestSelectedChips extends StatelessWidget {
  final List<String> ingredients;
  final ValueChanged<String> onRemove;

  const SuggestSelectedChips({
    super.key,
    required this.ingredients,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: ingredients.map((ing) {
          return Chip(
            label: Text(ing),
            deleteIcon: const Icon(Icons.close_rounded, size: 14),
            onDeleted: () => onRemove(ing),
            backgroundColor: AppColors.primaryLight,
            labelStyle: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          );
        }).toList(),
      ),
    );
  }
}
