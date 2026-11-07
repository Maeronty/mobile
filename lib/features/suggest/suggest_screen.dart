// =============================================================================
// MÀN HÌNH: GỢI Ý MÓN ĂN THÔNG MINH (tab "Gợi Ý AI")
// =============================================================================
//
// FILE NÀY CHỈ CHỨA GIAO DIỆN. Toàn bộ logic (chế độ tìm, thuật toán Match
// Score, sắp xếp) nằm trong `suggest_controller.dart`.
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
import '../../core/theme/app_colors.dart';
import '../../core/widgets/recipe_card.dart';
import 'suggest_controller.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gợi Ý Món Ăn Thông Minh'),
        actions: [
          PopupMenuButton<SuggestSortMode>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sắp xếp kết quả',
            onSelected: _controller.setSortMode,
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
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Mode Segmented Tabs
          Padding(
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
                  Expanded(
                    child: InkWell(
                      onTap: () => _controller.setSearchMode(SuggestSearchMode.byIngredients),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _controller.isIngredientMode ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.kitchen_rounded,
                              size: 18,
                              color: _controller.isIngredientMode
                                  ? Colors.white
                                  : Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Theo Tủ Lạnh',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _controller.isIngredientMode
                                    ? Colors.white
                                    : Theme.of(context).brightness == Brightness.dark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _controller.setSearchMode(SuggestSearchMode.byName),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_controller.isIngredientMode ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: !_controller.isIngredientMode
                                  ? Colors.white
                                  : Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tìm Theo Tên Món',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: !_controller.isIngredientMode
                                    ? Colors.white
                                    : Theme.of(context).brightness == Brightness.dark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Input Section based on mode
          if (!_controller.isIngredientMode) ...[
            // By Name Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: 'Nhập tên món ăn (ví dụ: Phở bò, Cá hồi, Salad...)',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  suffixIcon: _textController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _textController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ] else ...[
            // By Ingredients Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập nguyên liệu (VD: Thịt bò, Nấm, Trứng...)',
                        prefixIcon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                      ),
                      onSubmitted: _addIngredient,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: () => _addIngredient(_textController.text),
                    child: const Text('Thêm'),
                  ),
                ],
              ),
            ),

            // Quick add suggestions horizontal chips
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: SuggestController.quickSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final sug = SuggestController.quickSuggestions[index];
                  final isAlreadyAdded = _controller.isSelected(sug);
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
                        _removeIngredient(sug);
                      } else {
                        _addIngredient(sug);
                      }
                    },
                  );
                },
              ),
            ),

            // Active selected ingredients chips
            if (_controller.selectedIngredients.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _controller.selectedIngredients.map((ing) {
                    return Chip(
                      label: Text(ing),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      onDeleted: () => _removeIngredient(ing),
                      backgroundColor: AppColors.primaryLight,
                      labelStyle: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],

          const Divider(height: 12),

          // Match Results Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kết quả đề xuất (${results.length} món)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (_controller.isIngredientMode && _controller.selectedIngredients.isNotEmpty)
                  InkWell(
                    onTap: _controller.clearIngredients,
                    child: const Text(
                      'Xóa tất cả',
                      style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          // Recipe Results List
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restaurant_menu_rounded, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 14),
                          const Text(
                            'Chưa tìm thấy công thức phù hợp',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _controller.isIngredientMode
                                ? 'Hãy thử thêm các nguyên liệu phổ biến như: Thịt bò, Trứng, Bánh phở...'
                                : 'Thử tìm với từ khóa khác hoặc danh mục tổng quát hơn.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RecipeCard(
                            recipe: item,
                            isHorizontal: true,
                            onFavoriteToggled: () => setState(() {}),
                          ),
                          // Show matched & missing ingredients detail if in fridge mode
                          if (_controller.isIngredientMode && item.matchScore != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
                              child: Row(
                                children: [
                                  if (item.matchedIngredients.isNotEmpty) ...[
                                    const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Đã có: ${item.matchedIngredients.take(3).join(', ')}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: AppColors.primaryDark),
                                      ),
                                    ),
                                  ],
                                  if (item.missingIngredients.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.remove_circle_outline_rounded, size: 13, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Thiếu: ${item.missingIngredients.length} món',
                                      style: const TextStyle(fontSize: 11, color: Colors.orange),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

