// =============================================================================
// WIDGET: Ô NHẬP NGUYÊN LIỆU (tab "Tủ Lạnh Của Bạn")
// =============================================================================
//
// FLOW
//   Nhập tên → Enter hoặc bấm "Thêm" → `onAdd`.
//   KitchenBagScreen giữ TextEditingController để xoá ô nhập sau khi thêm.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PantryInputRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;

  const PantryInputRow({
    super.key,
    required this.controller,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Thêm nguyên liệu (ví dụ: Thịt bò, Trứng...)',
                prefixIcon: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAdd,
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }
}
