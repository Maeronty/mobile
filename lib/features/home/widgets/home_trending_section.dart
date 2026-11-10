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

  /// Tổng số món của danh mục (lưới chỉ hiện một phần).
  final int totalCount;

  /// null khi đã hiện hết → ẩn nút "Xem thêm".
  final VoidCallback? onShowMore;
  final VoidCallback onFavoriteToggled;

  const HomeTrendingSection({
    super.key,
    required this.title,
    required this.recipes,
    required this.totalCount,
    this.onShowMore,
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
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$totalCount món',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
          ),
        ),
        if (onShowMore != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: OutlinedButton(
              onPressed: onShowMore,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text('Xem thêm (${totalCount - recipes.length} món)'),
            ),
          ),
      ],
    );
  }
}
