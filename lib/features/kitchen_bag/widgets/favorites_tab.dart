// =============================================================================
// WIDGET: TAB "ĐÃ LƯU" (Túi Thần Kỳ)
// =============================================================================
//
// FLOW
//   - Chưa có món yêu thích → hiện lời hướng dẫn.
//   - Có món → lưới RecipeCard; bỏ thích trên card → `onFavoriteToggled`
//     → KitchenBagScreen build lại lưới.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/models/recipe.dart';
import '../../../core/widgets/recipe_card.dart';

class FavoritesTab extends StatelessWidget {
  final List<Recipe> recipes;
  final VoidCallback onFavoriteToggled;

  const FavoritesTab({
    super.key,
    required this.recipes,
    required this.onFavoriteToggled,
  });

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
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
      itemCount: recipes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        return RecipeCard(
          recipe: recipes[index],
          onFavoriteToggled: onFavoriteToggled,
        );
      },
    );
  }
}
