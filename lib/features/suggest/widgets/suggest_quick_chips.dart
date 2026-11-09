// =============================================================================
// WIDGET: CHIP THÊM NHANH NGUYÊN LIỆU (màn Gợi ý)
// =============================================================================
//
// FLOW
//   Chạm chip chưa chọn → `onAdd`; chạm chip đã chọn → `onRemove`.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SuggestQuickChips extends StatelessWidget {
  final List<String> suggestions;
  final bool Function(String ingredient) isSelected;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const SuggestQuickChips({
    super.key,
    required this.suggestions,
    required this.isSelected,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final sug = suggestions[index];
          final isAlreadyAdded = isSelected(sug);
          return ActionChip(
            avatar: Icon(
              isAlreadyAdded ? Icons.check_circle_rounded : Icons.add_rounded,
              size: 14,
              color: isAlreadyAdded ? AppColors.primary : Colors.grey,
            ),
            label: Text(sug),
            labelStyle: TextStyle(
              fontSize: 12,
              color: isAlreadyAdded ? AppColors.primaryDark : null,
            ),
            backgroundColor: isAlreadyAdded ? AppColors.primaryLight : null,
            onPressed: () {
              if (isAlreadyAdded) {
                onRemove(sug);
              } else {
                onAdd(sug);
              }
            },
          );
        },
      ),
    );
  }
}
