// =============================================================================
// MÀN HÌNH: TÚI THẦN KỲ (Kitchen Bag) — gồm 2 tab
// =============================================================================
//
// FILE NÀY CHỈ GHÉP CÁC KHU VỰC GIAO DIỆN; từng tab nằm trong `widgets/`.
//   - Tab 1 "Tủ Lạnh Của Bạn" → logic ở `pantry_controller.dart`.
//   - Tab 2 "Đã Lưu"          → logic ở `features/favorites/favorites_controller.dart`.
//
// FLOW UI
//   1. Nhập tên nguyên liệu → "Thêm"/Enter → `_addPantryItem()`
//      → PantryController.addIngredient → xoá ô nhập → setState.
//   2. Bấm × trên chip / "Dọn sạch tủ" → removeIngredient / clear → setState.
//   3. Bấm "Gợi ý món từ N nguyên liệu này" → mở SuggestScreen với danh sách
//      nguyên liệu hiện tại.
//   4. Tab "Đã Lưu": lưới RecipeCard của các món yêu thích; bỏ thích trên card
//      → callback `onFavoriteToggled` → setState để cập nhật lưới.
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../favorites/favorites_controller.dart';
import '../suggest/suggest_screen.dart';
import 'pantry_controller.dart';
import 'widgets/favorites_tab.dart';
import 'widgets/pantry_tab.dart';

class KitchenBagScreen extends StatefulWidget {
  const KitchenBagScreen({super.key});

  @override
  State<KitchenBagScreen> createState() => _KitchenBagScreenState();
}

class _KitchenBagScreenState extends State<KitchenBagScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _pantryInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pantryInputController.dispose();
    super.dispose();
  }

  void _addPantryItem() {
    final text = _pantryInputController.text.trim();
    if (text.isNotEmpty) {
      PantryController.instance.addIngredient(text);
      _pantryInputController.clear();
      setState(() {});
    }
  }

  void _openSuggest(List<String> pantryItems) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SuggestScreen(initialIngredients: pantryItems),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pantry = PantryController.instance;
    final favRecipes = FavoritesController.instance.favoriteRecipes;
    final pantryItems = pantry.ingredients;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Túi Thần Kỳ'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.kitchen_rounded),
              text: 'Tủ Lạnh Của Bạn (${pantryItems.length})',
            ),
            Tab(
              icon: const Icon(Icons.favorite_rounded),
              text: 'Đã Lưu (${favRecipes.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Kitchen Pantry
          PantryTab(
            items: pantryItems,
            inputController: _pantryInputController,
            onAdd: _addPantryItem,
            onClear: () => setState(() => pantry.clear()),
            onRemove: (item) => setState(() => pantry.removeIngredient(item)),
            onSuggest: () => _openSuggest(pantryItems),
          ),

          // TAB 2: Favorites List
          FavoritesTab(
            recipes: favRecipes,
            onFavoriteToggled: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}
