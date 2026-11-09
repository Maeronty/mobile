// =============================================================================
// WIDGET: DANH SÁCH NGUYÊN LIỆU TRONG TỦ (tab "Tủ Lạnh Của Bạn")
// =============================================================================
//
// FLOW
//   - Bấm × trên chip → `onRemove(item)`.
//   - Bấm "Dọn sạch tủ" → `onClear`.
//   KitchenBagScreen gọi PantryController rồi setState để cập nhật danh sách.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PantryItemList extends StatelessWidget {
  final List<String> items;
  final VoidCallback onClear;
  final ValueChanged<String> onRemove;

  const PantryItemList({
    super.key,
    required this.items,
    required this.onClear,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đang có ${items.length} nguyên liệu trong tủ:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton(
              onPressed: onClear,
              child: const Text('Dọn sạch tủ', style: TextStyle(color: AppColors.accent, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            return Chip(
              avatar: const CircleAvatar(
                backgroundColor: AppColors.primary,
                radius: 10,
                child: Icon(Icons.check, size: 12, color: Colors.white),
              ),
              label: Text(item),
              deleteIcon: const Icon(Icons.close_rounded, size: 16),
              onDeleted: () => onRemove(item),
              backgroundColor: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.dividerDark
                      : AppColors.dividerLight,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
