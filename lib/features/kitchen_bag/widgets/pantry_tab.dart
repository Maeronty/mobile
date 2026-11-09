// =============================================================================
// WIDGET: TAB "TỦ LẠNH CỦA BẠN" (Túi Thần Kỳ)
// =============================================================================
//
// VAI TRÒ
//   Ghép banner, ô nhập, danh sách nguyên liệu và nút gợi ý món. Không giữ state:
//   mọi hành động chuyển lên KitchenBagScreen qua callback.
//
// FLOW
//   Tủ trống → PantryEmptyView.
//   Tủ có đồ → PantryItemList + PantrySuggestBar.
// =============================================================================

import 'package:flutter/material.dart';
import 'pantry_empty_view.dart';
import 'pantry_info_banner.dart';
import 'pantry_input_row.dart';
import 'pantry_item_list.dart';
import 'pantry_suggest_bar.dart';

class PantryTab extends StatelessWidget {
  final List<String> items;
  final TextEditingController inputController;
  final VoidCallback onAdd;
  final VoidCallback onClear;
  final ValueChanged<String> onRemove;
  final VoidCallback onSuggest;

  const PantryTab({
    super.key,
    required this.items,
    required this.inputController,
    required this.onAdd,
    required this.onClear,
    required this.onRemove,
    required this.onSuggest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PantryInfoBanner(),
        PantryInputRow(controller: inputController, onAdd: onAdd),
        Expanded(
          child: items.isEmpty
              ? const PantryEmptyView()
              : PantryItemList(
                  items: items,
                  onClear: onClear,
                  onRemove: onRemove,
                ),
        ),
        if (items.isNotEmpty)
          PantrySuggestBar(itemCount: items.length, onPressed: onSuggest),
      ],
    );
  }
}
