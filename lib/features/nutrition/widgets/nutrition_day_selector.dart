// =============================================================================
// WIDGET: BỘ CHỌN NGÀY TRONG TUẦN (Dinh dưỡng)
// =============================================================================
//
// FLOW
//   Chạm chip ngày → `onSelected(index)` → NutritionController.selectDay
//   → thẻ tổng kết và danh sách bữa ăn đổi theo.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/theme/app_colors.dart';

class NutritionDaySelector extends StatelessWidget {
  final List<DailyPlan> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const NutritionDaySelector({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lịch trình các ngày trong tuần',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${days.length} ngày',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = days[index];
              final isSelected = index == selectedIndex;
              return FilterChip(
                selected: isSelected,
                selectedColor: AppColors.primary,
                label: Text(day.dayName),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => onSelected(index),
              );
            },
          ),
        ),
      ],
    );
  }
}
