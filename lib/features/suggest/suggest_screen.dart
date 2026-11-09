// =============================================================================
// MÀN HÌNH: GỢI Ý MÓN ĂN THÔNG MINH (tab "Gợi Ý AI")
// =============================================================================
//
// FILE NÀY CHỈ GHÉP CÁC KHU VỰC GIAO DIỆN; từng khu vực nằm trong `widgets/`.
// Toàn bộ logic (chế độ tìm, thuật toán Match Score, sắp xếp) nằm trong
// `suggest_controller.dart`.
//
// FLOW UI
//   1. initState → tạo SuggestController (nạp nguyên liệu ban đầu) và lắng nghe
//      controller: mỗi lần controller `notifyListeners()` → `setState` build lại.
//   2. AppBar ▸ nút sắp xếp → `setSortMode(...)`.
//   3. Thanh chọn chế độ: "Theo Tủ Lạnh" | "Tìm Theo Tên Món" → `setSearchMode`.
//   4. Chế độ tên món   : gõ chữ → `setState` → `results(query)` lọc lại ngay.
//      Chế độ nguyên liệu: nhập/ chạm chip gợi ý → add/remove nguyên liệu.
//   5. Danh sách kết quả: RecipeCard + dòng "Đã có / Thiếu" (chế độ nguyên liệu).
// =============================================================================

import 'package:flutter/material.dart';
import 'suggest_controller.dart';
import 'widgets/suggest_empty_view.dart';
import 'widgets/suggest_ingredient_input.dart';
import 'widgets/suggest_mode_tabs.dart';
import 'widgets/suggest_name_input.dart';
import 'widgets/suggest_quick_chips.dart';
import 'widgets/suggest_result_tile.dart';
import 'widgets/suggest_results_header.dart';
import 'widgets/suggest_selected_chips.dart';
import 'widgets/suggest_sort_menu.dart';

class SuggestScreen extends StatefulWidget {
  /// Nguyên liệu truyền sẵn (VD: từ nút "Gợi ý món" ở Túi Thần Kỳ).
  final List<String>? initialIngredients;

  const SuggestScreen({super.key, this.initialIngredients});

  @override
  State<SuggestScreen> createState() => _SuggestScreenState();
}

class _SuggestScreenState extends State<SuggestScreen> {
  late final SuggestController _controller;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = SuggestController(initialIngredients: widget.initialIngredients);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  /// Thêm nguyên liệu; chỉ xoá ô nhập khi thêm thành công.
  void _addIngredient(String name) {
    if (_controller.addIngredient(name)) {
      _textController.clear();
    }
  }

  void _removeIngredient(String name) => _controller.removeIngredient(name);

  @override
  Widget build(BuildContext context) {
    final results = _controller.results(_textController.text);
    final isIngredientMode = _controller.isIngredientMode;
    final selectedIngredients = _controller.selectedIngredients;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gợi Ý Món Ăn Thông Minh'),
        actions: [
          SuggestSortMenu(onSelected: _controller.setSortMode),
        ],
      ),
      body: Column(
        children: [
          SuggestModeTabs(
            isIngredientMode: isIngredientMode,
            onModeSelected: _controller.setSearchMode,
          ),

          // Input Section based on mode
          if (!isIngredientMode) ...[
            SuggestNameInput(
              controller: _textController,
              onChanged: () => setState(() {}),
              onClear: () {
                _textController.clear();
                setState(() {});
              },
            ),
          ] else ...[
            SuggestIngredientInput(
              controller: _textController,
              onAdd: _addIngredient,
            ),
            SuggestQuickChips(
              suggestions: SuggestController.quickSuggestions,
              isSelected: _controller.isSelected,
              onAdd: _addIngredient,
              onRemove: _removeIngredient,
            ),
            if (selectedIngredients.isNotEmpty)
              SuggestSelectedChips(
                ingredients: selectedIngredients,
                onRemove: _removeIngredient,
              ),
          ],

          const Divider(height: 12),

          SuggestResultsHeader(
            resultCount: results.length,
            showClearAll: isIngredientMode && selectedIngredients.isNotEmpty,
            onClearAll: _controller.clearIngredients,
          ),

          // Recipe Results List
          Expanded(
            child: results.isEmpty
                ? SuggestEmptyView(isIngredientMode: isIngredientMode)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => SuggestResultTile(
                      recipe: results[index],
                      isIngredientMode: isIngredientMode,
                      onFavoriteToggled: () => setState(() {}),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
