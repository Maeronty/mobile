// =============================================================================
// WIDGET: THANH "GỢI Ý MÓN TỪ N NGUYÊN LIỆU" (tab "Tủ Lạnh Của Bạn")
// =============================================================================
//
// FLOW
//   Bấm nút → `onPressed` → KitchenBagScreen mở SuggestScreen với danh sách
//   nguyên liệu hiện tại. Chỉ hiển thị khi tủ có ít nhất 1 nguyên liệu.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PantrySuggestBar extends StatelessWidget {
  final int itemCount;
  final VoidCallback onPressed;

  const PantrySuggestBar({
    super.key,
    required this.itemCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.dividerDark
                : AppColors.dividerLight,
          ),
        ),
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: AppColors.primary,
          ),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(
            'Gợi ý món từ $itemCount nguyên liệu này',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
