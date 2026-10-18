import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../../theme/app_colors.dart';
import '../../services/app_state.dart';
import '../../widgets/recipe_card.dart';

class SuggestScreen extends StatefulWidget {
  final List<String>? initialIngredients;

  const SuggestScreen({super.key, this.initialIngredients});

  @override
  State<SuggestScreen> createState() => _SuggestScreenState();
}

class _SuggestScreenState extends State<SuggestScreen> {
  // Mode: 0 for "Tìm theo tên", 1 for "Tìm theo nguyên liệu (Tủ lạnh)"
  int _searchMode = 1;
  final TextEditingController _textController = TextEditingController();
  final List<String> _selectedIngredients = [];
  String _sortMode = 'match'; // 'match', 'rating', 'time', 'calories'

  final List<String> _quickSuggestions = [
    'Thịt bò',
    'Ức gà',
    'Tôm tươi',
    'Cá hồi',
    'Trứng gà',
    'Cà chua',
    'Hành tây',
    'Bánh phở',
    'Mì Ý',
    'Xà lách',
    'Măng tây',
    'Bơ lạt',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialIngredients != null && widget.initialIngredients!.isNotEmpty) {
      _selectedIngredients.addAll(widget.initialIngredients!);
      _searchMode = 1;
    } else {
      // Default initial ingredients from app pantry
      final pantry = AppState().pantryIngredients;
      if (pantry.isNotEmpty) {
        _selectedIngredients.addAll(pantry);
      } else {
        _selectedIngredients.addAll(['Thịt bò', 'Bánh phở', 'Tỏi']);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _addIngredient(String name) {
    final clean = name.trim();
    if (clean.isNotEmpty && !_selectedIngredients.contains(clean)) {
      setState(() {
        _selectedIngredients.add(clean);
      });
      _textController.clear();
    }
  }

  void _removeIngredient(String name) {
    setState(() {
      _selectedIngredients.remove(name);
    });
  }

  List<Recipe> _getFilteredRecipes() {
    final appState = AppState();

    if (_searchMode == 0) {
      // Search by name / keyword
      final query = _textController.text.toLowerCase().trim();
      var list = appState.recipes;
      if (query.isNotEmpty) {
        list = list.where((r) {
          final titleMatch = r.title.toLowerCase().contains(query);
          final catMatch = r.category.toLowerCase().contains(query);
          final tagMatch = r.tags.any((t) => t.toLowerCase().contains(query));
          return titleMatch || catMatch || tagMatch;
        }).toList();
      }
      return _applySorting(list);
    } else {
      // Search by ingredients (Smart Match)
      var list = appState.matchRecipesByIngredients(_selectedIngredients);
      return _applySorting(list);
    }
  }

  List<Recipe> _applySorting(List<Recipe> input) {
    final list = List<Recipe>.from(input);
    switch (_sortMode) {
      case 'rating':
        list.sort((a, b) => b.averageRating.compareTo(a.averageRating));
        break;
      case 'time':
        list.sort((a, b) => a.cookTimeMinutes.compareTo(b.cookTimeMinutes));
        break;
      case 'calories':
        list.sort((a, b) => a.calories.compareTo(b.calories));
        break;
      case 'match':
      default:
        if (_searchMode == 1) {
          list.sort((a, b) => (b.matchScore ?? 0).compareTo(a.matchScore ?? 0));
        }
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final results = _getFilteredRecipes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gợi Ý Món Ăn Thông Minh'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sắp xếp kết quả',
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'match',
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Text('Độ phù hợp cao nhất'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'rating',
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Text('Đánh giá cao nhất'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'time',
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Nấu nhanh nhất'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'calories',
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
                      onTap: () => setState(() => _searchMode = 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _searchMode == 1 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.kitchen_rounded,
                              size: 18,
                              color: _searchMode == 1
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
                                color: _searchMode == 1
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
                      onTap: () => setState(() => _searchMode = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _searchMode == 0 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: _searchMode == 0
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
                                color: _searchMode == 0
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
          if (_searchMode == 0) ...[
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
                itemCount: _quickSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final sug = _quickSuggestions[index];
                  final isAlreadyAdded = _selectedIngredients.contains(sug);
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
            if (_selectedIngredients.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedIngredients.map((ing) {
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
                if (_searchMode == 1 && _selectedIngredients.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() => _selectedIngredients.clear()),
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
                            _searchMode == 1
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
                          if (_searchMode == 1 && item.matchScore != null)
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

