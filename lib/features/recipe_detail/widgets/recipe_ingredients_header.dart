// =============================================================================
// WIDGET: TIÊU ĐỀ NGUYÊN LIỆU (Chi tiết công thức)
// =============================================================================
//
// HIỂN THỊ
//   "Nguyên liệu cần chuẩn bị" + "N nguyên liệu (x/N đã chuẩn bị)".
//   (Bộ chỉnh khẩu phần [−] N phần [+] đã được gỡ — định lượng giữ như gốc.)
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class RecipeIngredientsHeader extends StatelessWidget {
  final int totalCount;
  final int checkedCount;

  const RecipeIngredientsHeader({
    super.key,
    required this.totalCount,
    required this.checkedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}
