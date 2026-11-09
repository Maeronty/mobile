// =============================================================================
// WIDGET: BỘ LỌC THỂ LOẠI MÓN ĂN (Surprise Me)
// =============================================================================
//
// FLOW
//   Chạm chip → `onToggle(category)`; có thể chọn nhiều thể loại cùng lúc.
//   Không chọn thể loại nào → hiển thị "Tất cả".
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SurpriseCategoryFilter extends StatelessWidget {
  final List<String> categories;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const SurpriseCategoryFilter({
    super.key,
    required this.categories,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Thể loại món ăn',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              selected.isEmpty ? 'Tất cả' : '${selected.length} đã chọn',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final isSelected = selected.contains(cat);
            return FilterChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: AppColors.primary,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              backgroundColor: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight),
                ),
              ),
              onSelected: (_) => onToggle(cat),
            );
          }).toList(),
        ),
      ],
    );
  }
}
