// =============================================================================
// WIDGET: TRẠNG THÁI KHÔNG CÓ KẾT QUẢ (màn Gợi ý)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị khi không có món phù hợp; lời gợi ý thay đổi theo chế độ tìm.
// =============================================================================

import 'package:flutter/material.dart';

class SuggestEmptyView extends StatelessWidget {
  final bool isIngredientMode;

  const SuggestEmptyView({super.key, required this.isIngredientMode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'Chưa tìm thấy công thức phù hợp',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              isIngredientMode
                  ? 'Hãy thử thêm các nguyên liệu phổ biến như: Thịt bò, Trứng, Bánh phở...'
                  : 'Thử tìm với từ khóa khác hoặc danh mục tổng quát hơn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
