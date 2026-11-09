// =============================================================================
// WIDGET: Ô TÌM THEO TÊN MÓN (màn Gợi ý)
// =============================================================================
//
// FLOW
//   Gõ chữ → `onChanged` → SuggestScreen build lại → kết quả lọc theo từ khoá.
//   Bấm nút xoá (chỉ hiện khi có chữ) → `onClear`.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SuggestNameInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onClear;

  const SuggestNameInput({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Nhập tên món ăn (ví dụ: Phở bò, Cá hồi, Salad...)',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: onClear,
                )
              : null,
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}
