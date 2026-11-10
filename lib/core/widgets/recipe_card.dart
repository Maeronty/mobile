// =============================================================================
// WIDGET DÙNG CHUNG: THẺ CÔNG THỨC (RecipeCard)
// =============================================================================
//
// Dùng ở Home, Gợi ý, Túi Thần Kỳ. Có 2 kiểu bố cục: dọc (lưới) và ngang (list).
//
// FLOW
//   1. Chạm vào thẻ → mở RecipeDetailScreen(recipeId).
//   2. Chạm icon trái tim → FavoritesController.toggleFavorite(recipe.id)
//      → gọi `onFavoriteToggled` để màn hình cha build lại (VD: Túi Thần Kỳ
//      cần bỏ món khỏi lưới "Đã Lưu").
// =============================================================================

import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../theme/app_colors.dart';
import '../../features/favorites/favorites_controller.dart';
import '../../features/recipe_detail/recipe_detail_screen.dart';
import 'difficulty_stars.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool isHorizontal;
  final VoidCallback? onFavoriteToggled;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.isHorizontal = false,
    this.onFavoriteToggled,
  });

  @override
  Widget build(BuildContext context) {
    final isFav = FavoritesController.instance.isFavorite(recipe.id);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.dividerDark
                : AppColors.dividerLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: isHorizontal
            ? _buildHorizontalLayout(context, isFav)
            : _buildVerticalLayout(context, isFav),
      ),
    );
  }

  Widget _buildVerticalLayout(BuildContext context, bool isFav) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image & Badges
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(
                recipe.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.restaurant, color: Colors.grey),
                ),
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Category Badge
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  recipe.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Favorite Button
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFav ? AppColors.accent : Colors.white,
                    size: 22,
                  ),
                  onPressed: () {
                    FavoritesController.instance.toggleFavorite(recipe.id);
                    onFavoriteToggled?.call();
                  },
                ),
              ),
            ),
            // Match score if available
            if (recipe.matchScore != null)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 14,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(recipe.matchScore! * 100).toInt()}% Phù hợp',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // Info Section
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: DifficultyStars(
                      difficulty: recipe.difficulty,
                      size: 11,
                      showLabel: false,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        recipe.cookTimeShortLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 13,
                        color: AppColors.accentOrange,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        recipe.caloriesLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentOrange,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        recipe.totalRatings == 0
                            ? '—'
                            : recipe.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalLayout(BuildContext context, bool isFav) {
    return Row(
      children: [
        // Image
        SizedBox(
          width: 120,
          height: 110,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                recipe.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.restaurant, color: Colors.grey),
                ),
              ),
              if (recipe.matchScore != null)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(recipe.matchScore! * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        recipe.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        FavoritesController.instance.toggleFavorite(recipe.id);
                        onFavoriteToggled?.call();
                      },
                      child: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav ? AppColors.accent : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                DifficultyStars(difficulty: recipe.difficulty, size: 12),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      recipe.cookTimeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 13,
                      color: AppColors.accentOrange,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      recipe.caloriesLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.accentOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
