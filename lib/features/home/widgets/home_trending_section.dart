// =============================================================================
// WIDGET: KHU VỰC "MÓN ĂN THỊNH HÀNH" (trang chủ)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị tiêu đề, số món và lưới 2 cột theo danh sách đã lọc từ HomeController.
//
// FLOW
//   Thả tim trên card → `onFavoriteToggled` → HomeScreen build lại.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/models/recipe.dart';
import '../../../core/widgets/recipe_card.dart';

class HomeTrendingSection extends StatelessWidget {
  final String title;
  final List<Recipe> recipes;
  final VoidCallback onFavoriteToggled;

  const HomeTrendingSection({
    super.key,
    required this.title,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${recipes.length} món',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recipes.length,
                gridDelegate: RecipeCard.gridDelegate(context, constraints.maxWidth),
                itemBuilder: (context, index) {
                  return RecipeCard(
                    recipe: recipes[index],
                    onFavoriteToggled: onFavoriteToggled,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
