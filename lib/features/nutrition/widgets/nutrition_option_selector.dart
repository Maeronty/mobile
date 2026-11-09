// =============================================================================
// WIDGET: BỘ CHỌN DẠNG CHIP (Đối tượng / Mục tiêu sức khoẻ)
// =============================================================================
//
// VAI TRÒ
//   Dùng chung cho cả 2 bộ chọn; hai bộ chỉ khác tiêu đề, danh sách lựa chọn
//   và cách ghép nhãn (`labelBuilder`).
//
// FLOW
//   Chạm chip → `onSelected(option.id)` → NutritionController lưu lựa chọn.
//   Thực đơn CHƯA tạo lại cho tới khi người dùng bấm nút tạo.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../nutrition_controller.dart';

class NutritionOptionSelector extends StatelessWidget {
  final String title;
  final List<NutritionOption> options;
  final String selectedId;
  final String Function(NutritionOption option) labelBuilder;
  final ValueChanged<String> onSelected;

  const NutritionOptionSelector({
    super.key,
    required this.title,
    required this.options,
    required this.selectedId,
    required this.labelBuilder,
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
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = option.id == selectedId;
              return ChoiceChip(
                label: Text(labelBuilder(option)),
                selected: isSelected,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (_) => onSelected(option.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
