// =============================================================================
// WIDGET: KHU VỰC "NẤU NHANH GỌN" (trang chủ)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị hàng ngang các món nấu dưới 25 phút do HomeController cung cấp.
//
// FLOW
//   Thả tim trên card → `onFavoriteToggled` → HomeScreen build lại.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/models/recipe.dart';
import '../../../core/widgets/recipe_card.dart';

class HomeFastRecipesSection extends StatelessWidget {
  final List<Recipe> recipes;
  final VoidCallback onFavoriteToggled;

  const HomeFastRecipesSection({
    super.key,
    required this.recipes,
    required this.onFavoriteToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
              SizedBox(width: 6),
              Text(
                'Nấu nhanh gọn (Dưới 25 phút)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recipes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 180,
                child: RecipeCard(
                  recipe: recipes[index],
                  onFavoriteToggled: onFavoriteToggled,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
