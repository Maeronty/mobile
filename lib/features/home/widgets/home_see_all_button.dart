// =============================================================================
// WIDGET: NÚT "XEM TẤT CẢ" DƯỚI LƯỚI XEM TRƯỚC (Home)
// =============================================================================
//
// FLOW
//   Hiện khi danh mục còn món ngoài phần xem trước → bấm → `onPressed` →
//   HomeScreen mở màn "Xem tất cả" (danh sách đầy đủ có phân trang).
//
// HIỂN THỊ
//   Nút viền tròn, rộng hết lưới: "Xem tất cả 1.829 món  →".
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../recipe_list/recipe_list_screen.dart';

class HomeSeeAllButton extends StatelessWidget {
  final int total;
  final VoidCallback onPressed;

  const HomeSeeAllButton({super.key, required this.total, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        child: SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Xem tất cả ${formatCount(total)} món',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
