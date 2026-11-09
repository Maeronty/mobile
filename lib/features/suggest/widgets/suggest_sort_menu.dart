// =============================================================================
// WIDGET: MENU SẮP XẾP KẾT QUẢ (AppBar màn Gợi ý)
// =============================================================================
//
// FLOW
//   Chọn một tiêu chí → `onSelected(mode)` → SuggestController.setSortMode
//   → danh sách kết quả sắp xếp lại.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../suggest_controller.dart';

class SuggestSortMenu extends StatelessWidget {
  final ValueChanged<SuggestSortMode> onSelected;

  const SuggestSortMenu({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SuggestSortMode>(
      icon: const Icon(Icons.sort_rounded),
      tooltip: 'Sắp xếp kết quả',
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: SuggestSortMode.match,
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Text('Độ phù hợp cao nhất'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: SuggestSortMode.rating,
          child: Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Text('Đánh giá cao nhất'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: SuggestSortMode.time,
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 18),
              SizedBox(width: 8),
              Text('Nấu nhanh nhất'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: SuggestSortMode.calories,
          child: Row(
            children: [
              Icon(Icons.local_fire_department_outlined, color: AppColors.accentOrange, size: 18),
              SizedBox(width: 8),
              Text('Ít calo nhất'),
            ],
          ),
        ),
      ],
    );
  }
}
