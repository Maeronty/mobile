// =============================================================================
// WIDGET: TRẠNG THÁI TỦ LẠNH TRỐNG (tab "Tủ Lạnh Của Bạn")
// =============================================================================
//
// VAI TRÒ
//   Hiển thị khi chưa có nguyên liệu nào trong tủ.
// =============================================================================

import 'package:flutter/material.dart';

class PantryEmptyView extends StatelessWidget {
  const PantryEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.kitchen_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Tủ lạnh hiện đang trống',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Thêm một vài nguyên liệu để bắt đầu tìm món ăn ngon!',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
