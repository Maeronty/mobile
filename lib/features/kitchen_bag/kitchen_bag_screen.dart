// =============================================================================
// MÀN HÌNH: TÚI THẦN KỲ (Kitchen Bag) — gồm 2 tab
// =============================================================================
//
// FILE NÀY CHỈ CHỨA GIAO DIỆN.
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
import '../../core/models/recipe.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/recipe_card.dart';
import '../favorites/favorites_controller.dart';
import '../suggest/suggest_screen.dart';
import 'pantry_controller.dart';

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
          _buildPantryTab(context, pantry, pantryItems),

          // TAB 2: Favorites List
          _buildFavoritesTab(context, favRecipes),
        ],
      ),
    );
  }

  Widget _buildPantryTab(BuildContext context, PantryController pantry, List<String> pantryItems) {
    return Column(
      children: [
        // Top description banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppColors.primary.withOpacity(0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Kho nguyên liệu gia đình',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Lưu trữ những gì bạn đang có trong tủ lạnh. Bếp Việt sẽ tự động tìm các món bạn có thể nấu ngay!',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),

        // Input row
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pantryInputController,
                  decoration: InputDecoration(
                    hintText: 'Thêm nguyên liệu (ví dụ: Thịt bò, Trứng...)',
                    prefixIcon: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _addPantryItem(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addPantryItem,
                child: const Text('Thêm'),
              ),
            ],
          ),
        ),

        // Pantry items grid / wrap
        Expanded(
          child: pantryItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.kitchen_outlined, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'Tủ lạnh hiện đang trống',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thêm một vài nguyên liệu để bắt đầu tìm món ăn ngon!',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đang có ${pantryItems.length} nguyên liệu trong tủ:',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => pantry.clear());
                          },
                          child: const Text('Dọn sạch tủ', style: TextStyle(color: AppColors.accent, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pantryItems.map((item) {
                        return Chip(
                          avatar: const CircleAvatar(
                            backgroundColor: AppColors.primary,
                            radius: 10,
                            child: Icon(Icons.check, size: 12, color: Colors.white),
                          ),
                          label: Text(item),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                          onDeleted: () {
                            setState(() => pantry.removeIngredient(item));
                          },
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
                ),
        ),

        // Bottom CTA: Suggest recipes using current pantry
        if (pantryItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.dividerDark
                      : AppColors.dividerLight,
                ),
              ),
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  'Gợi ý món từ ${pantryItems.length} nguyên liệu này',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SuggestScreen(initialIngredients: pantryItems),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFavoritesTab(BuildContext context, List<Recipe> favRecipes) {
    if (favRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Chưa có món ăn yêu thích nào',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Nhấn vào biểu tượng trái tim trên bất kỳ món ăn nào để lưu lại tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favRecipes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        return RecipeCard(
          recipe: favRecipes[index],
          onFavoriteToggled: () => setState(() {}),
        );
      },
    );
  }
}

