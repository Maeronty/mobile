// =============================================================================
// MÀN HÌNH: TÚI THẦN KỲ (Kitchen Bag) — các món đã lưu (yêu thích)
// =============================================================================
//
// FILE NÀY CHỈ GHÉP GIAO DIỆN; danh sách nằm trong `widgets/favorites_tab.dart`,
// logic ở `features/favorites/favorites_controller.dart`.
// (Tab "Tủ Lạnh Của Bạn" đã được gỡ — tìm món theo nguyên liệu nằm ở tab Gợi Ý.)
//
// FLOW UI
//   1. Mở tab → lưới RecipeCard của các món yêu thích (chưa có → lời hướng dẫn).
//   2. Danh mục món tải ngầm xong / danh sách yêu thích đổi (đăng nhập, đồng bộ,
//      bỏ thích ở màn khác) → build lại.
//   3. Bỏ thích trên card → `onFavoriteToggled` → build lại lưới.
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/data/recipe_repository.dart';
import '../favorites/favorites_controller.dart';
import 'widgets/favorites_tab.dart';

class KitchenBagScreen extends StatefulWidget {
  const KitchenBagScreen({super.key});

  @override
  State<KitchenBagScreen> createState() => _KitchenBagScreenState();
}

class _KitchenBagScreenState extends State<KitchenBagScreen> {
  @override
  void initState() {
    super.initState();
    // Danh mục món tải ngầm sau khi mở app → tải xong thì dựng lại lưới Yêu thích.
    RecipeRepository.instance.addListener(_onStateChanged);
    FavoritesController.instance.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RecipeRepository.instance.removeListener(_onStateChanged);
    FavoritesController.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favRecipes = FavoritesController.instance.favoriteRecipes;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Túi Thần Kỳ'),
            Text(
              'Đã Lưu (${favRecipes.length})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: FavoritesTab(
        recipes: favRecipes,
        onFavoriteToggled: () => setState(() {}),
      ),
    );
  }
}
