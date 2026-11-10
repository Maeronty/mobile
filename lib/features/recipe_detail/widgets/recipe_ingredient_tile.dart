// =============================================================================
// WIDGET: MỘT DÒNG NGUYÊN LIỆU (Chi tiết công thức)
// =============================================================================
//
// FLOW
//   Chạm dòng → `onTap` → tick "đã chuẩn bị"; dòng đã tick có chữ gạch ngang.
//
// LƯU Ý
//   `amountText` đã được controller nhân theo khẩu phần và định dạng sẵn.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/models/recipe.dart';
import '../../../core/theme/app_colors.dart';

class RecipeIngredientTile extends StatelessWidget {
  final IngredientItem item;
  final String amountText;
  final bool isChecked;
  final VoidCallback onTap;

  const RecipeIngredientTile({
    super.key,
    required this.item,
    required this.amountText,
    required this.isChecked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isChecked
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isChecked ? AppColors.primary : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 14,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  color: isChecked ? Colors.grey : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$amountText ${item.unit}'.trim(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isChecked ? Colors.grey : AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
