// =============================================================================
// WIDGET: MỘT DÒNG NGUYÊN LIỆU (Chi tiết công thức)
// =============================================================================
//
// FLOW
//   Chạm dòng → `onTap` → tick "đã chuẩn bị"; dòng đã tick có chữ gạch ngang.
//
// BỐ CỤC
//   [○] Tên nguyên liệu                       150 g
//       ghi chú nhỏ màu xám (nếu có)
//   Cột định lượng tối đa ~40% chiều ngang, tự xuống dòng → đơn vị dài không
//   bao giờ tràn ra ngoài màn hình.
//
// LƯU Ý
//   `amountText` đã được controller định dạng sẵn ("200", "1.5", "").
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
    final amount = '$amountText ${item.unit}'.trim();
    final note = item.note;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 14,
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked ? Colors.grey : null,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 2),
                      Text(note, style: const TextStyle(fontSize: 12, height: 1.35, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              if (amount.isNotEmpty) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.4),
                  child: Text(
                    amount,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isChecked ? Colors.grey : AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
