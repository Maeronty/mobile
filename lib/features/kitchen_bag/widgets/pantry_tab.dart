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
import '../../../core/data/recipe_repository.dart';
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
        TextButton.icon(
          icon: const Icon(Icons.list_alt),
          label: const Text('Chọn nguyên liệu từ Spoonacular'),
          onPressed: () async {
            final choices = RecipeRepository.instance.ingredients
                .where((name) => !items.contains(name)).toList()..sort();
            final selected = await showDialog<String>(context: context,
              builder: (context) => SimpleDialog(
                title: const Text('Nguyên liệu Spoonacular'),
                children: [
                  if (choices.isEmpty) const Padding(
                    padding: EdgeInsets.all(16), child: Text('Bạn đã thêm tất cả nguyên liệu.')),
                  for (final name in choices) SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, name), child: Text(name)),
                ],
              ));
            if (selected != null && context.mounted) {
              inputController.text = selected;
              onAdd();
            }
          },
        ),
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
