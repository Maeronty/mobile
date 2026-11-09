// =============================================================================
// WIDGET: Ô NHẬP NGUYÊN LIỆU (màn Gợi ý)
// =============================================================================
//
// FLOW
//   Enter hoặc bấm "Thêm" → `onAdd(text)`. SuggestScreen chỉ xoá ô nhập khi
//   nguyên liệu được thêm thành công (không rỗng, không trùng).
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SuggestIngredientInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onAdd;

  const SuggestIngredientInput({
    super.key,
    required this.controller,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Nhập nguyên liệu (VD: Thịt bò, Nấm, Trứng...)',
                prefixIcon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
              ),
              onSubmitted: onAdd,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onPressed: () => onAdd(controller.text),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }
}
