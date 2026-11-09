// =============================================================================
// WIDGET: MỘT KẾT QUẢ GỢI Ý (màn Gợi ý)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị RecipeCard ngang. Ở chế độ nguyên liệu, nếu món có điểm khớp thì
//   thêm dòng "Đã có / Thiếu".
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/models/recipe.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/recipe_card.dart';

class SuggestResultTile extends StatelessWidget {
  final Recipe recipe;
  final bool isIngredientMode;
  final VoidCallback onFavoriteToggled;

  const SuggestResultTile({
    super.key,
    required this.recipe,
    required this.isIngredientMode,
    required this.onFavoriteToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RecipeCard(
          recipe: recipe,
          isHorizontal: true,
          onFavoriteToggled: onFavoriteToggled,
        ),
        // Show matched & missing ingredients detail if in fridge mode
        if (isIngredientMode && recipe.matchScore != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
            child: Row(
              children: [
                if (recipe.matchedIngredients.isNotEmpty) ...[
                  const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Đã có: ${recipe.matchedIngredients.take(3).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.primaryDark),
                    ),
                  ),
                ],
                if (recipe.missingIngredients.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.remove_circle_outline_rounded, size: 13, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Thiếu: ${recipe.missingIngredients.length} món',
                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
