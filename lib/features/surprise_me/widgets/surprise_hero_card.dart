// =============================================================================
// WIDGET: THẺ MÓN ĂN TRÚNG THƯỞNG (Surprise Me — trạng thái Result)
// =============================================================================
//
// FLOW
//   - Nút trái tim → FavoritesController.toggleFavorite. Nút tự cập nhật nhờ
//     ListenableBuilder nên không cần màn hình build lại.
//   - "Xem công thức" → `onViewRecipe`; "Nấu ngay" → `onCookNow`.
//
// LƯU Ý
//   Ảnh lỗi → hiện icon nhà hàng trên nền màu nhạt.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/models/recipe.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/difficulty_stars.dart';
import '../../favorites/favorites_controller.dart';
import 'surprise_stat_item.dart';

class SurpriseHeroCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onViewRecipe;
  final VoidCallback onCookNow;

  const SurpriseHeroCard({
    super.key,
    required this.recipe,
    required this.onViewRecipe,
    required this.onCookNow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favorites = FavoritesController.instance;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh món ăn lớn
          Stack(
            children: [
              SizedBox(
                height: 220,
                width: double.infinity,
                child: Image.network(
                  ApiClient.imageUrl(recipe.imageAsset),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.primaryLight,
                    child: const Center(
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              // Badge Thể loại
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    recipe.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Nút Yêu thích
              Positioned(
                top: 10,
                right: 10,
                child: ListenableBuilder(
                  listenable: favorites,
                  builder: (context, _) {
                    final isFav = favorites.isFavorite(recipe.id);
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav ? Colors.redAccent : Colors.white,
                        ),
                        onPressed: () => favorites.toggleFavorite(recipe.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Nội dung thẻ
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  recipe.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Thông số nhanh: Thời gian, Calo, Độ khó, Khẩu phần
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    SurpriseStatItem(
                      icon: Icons.access_time_rounded,
                      label: recipe.cookTimeLabel,
                      sublabel: 'Thời gian',
                      color: AppColors.primary,
                    ),
                    SurpriseStatItem(
                      icon: Icons.local_fire_department_rounded,
                      label: recipe.caloriesLabel,
                      sublabel: 'Năng lượng',
                      color: Colors.deepOrange,
                    ),
                    SurpriseStatItem(
                      icon: Icons.people_outline_rounded,
                      label: recipe.servingsLabel,
                      sublabel: 'Khẩu phần',
                      color: Colors.blue,
                    ),
                    Column(
                      children: [
                        DifficultyStars(difficulty: recipe.difficulty),
                        const SizedBox(height: 4),
                        Text(
                          recipe.difficulty,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Hàng nút hành động: Xem công thức & Nấu ngay
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onViewRecipe,
                        icon: const Icon(Icons.menu_book_rounded),
                        label: const Text('Xem công thức'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onCookNow,
                        icon: const Icon(Icons.play_circle_fill_rounded,
                            color: Colors.white),
                        label: const Text('Nấu ngay'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
