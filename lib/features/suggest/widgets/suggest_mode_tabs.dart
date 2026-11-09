// =============================================================================
// WIDGET: THANH CHỌN CHẾ ĐỘ TÌM (màn Gợi ý)
// =============================================================================
//
// FLOW
//   Chạm "Theo Tủ Lạnh" / "Tìm Theo Tên Món" → `onModeSelected(mode)`
//   → SuggestController.setSearchMode → màn hình đổi ô nhập tương ứng.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../suggest_controller.dart';

class SuggestModeTabs extends StatelessWidget {
  final bool isIngredientMode;
  final ValueChanged<SuggestSearchMode> onModeSelected;

  const SuggestModeTabs({
    super.key,
    required this.isIngredientMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.dividerDark
                : AppColors.dividerLight,
          ),
        ),
        child: Row(
          children: [
            _ModeTab(
              icon: Icons.kitchen_rounded,
              label: 'Theo Tủ Lạnh',
              isActive: isIngredientMode,
              onTap: () => onModeSelected(SuggestSearchMode.byIngredients),
            ),
            _ModeTab(
              icon: Icons.search_rounded,
              label: 'Tìm Theo Tên Món',
              isActive: !isIngredientMode,
              onTap: () => onModeSelected(SuggestSearchMode.byName),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một ô trong thanh chọn chế độ; ô đang chọn có nền màu chính và chữ trắng.
class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contentColor = isActive
        ? Colors.white
        : Theme.of(context).brightness == Brightness.dark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: contentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: contentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
