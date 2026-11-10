// =============================================================================
// WIDGET: THẺ MÓN ẢNH LỚN (RecipeTileCard) — dùng ở lưới Home / danh mục
// =============================================================================
//
// GIAO DIỆN
//   Ảnh phủ kín thẻ, bo góc 20; lớp mờ tối ở nửa dưới để chữ trắng luôn đọc
//   được; nhãn danh mục + tên món (2 dòng) + dòng phụ (số nguyên liệu, calo).
//   Nút tim góc trên phải.
//
// FLOW
//   1. Nhấn thẻ → thu nhỏ nhẹ (Pressable) → mở RecipeDetailScreen bằng
//      `recipeRoute`; ảnh bay sang màn chi tiết bằng Hero [heroTag].
//      Truyền sẵn [recipe] (bản tóm tắt) để màn chi tiết hiện ngay ảnh + tên
//      trong lúc tải phần còn lại.
//   2. Nhấn tim → FavoritesController.toggleFavorite → tim phóng to rồi về
//      (AnimatedScale) và đổi màu.
//
// LƯU Ý
//   [heroTag] phải khác nhau nếu cùng một món xuất hiện 2 chỗ trên cùng màn
//   (VD banner và lưới) — Flutter báo lỗi khi trùng tag.
// =============================================================================

import 'package:flutter/material.dart';

import '../../features/favorites/favorites_controller.dart';
import '../../features/recipe_detail/recipe_detail_screen.dart';
import '../models/recipe_summary.dart';
import '../motion/motion.dart';
import '../motion/pressable.dart';
import '../motion/recipe_route.dart';
import 'app_network_image.dart';

class RecipeTileCard extends StatelessWidget {
  final RecipeSummary recipe;
  final String heroTag;

  const RecipeTileCard({super.key, required this.recipe, required this.heroTag});

  static void open(BuildContext context, RecipeSummary recipe, String heroTag) {
    Navigator.of(context).push(recipeRoute(
      RecipeDetailScreen(recipeId: recipe.id, preview: recipe, heroTag: heroTag),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => open(context, recipe, heroTag),
      child: Semantics(
        button: true,
        label: recipe.title,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(tag: heroTag, child: AppNetworkImage(url: recipe.image)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1],
                    colors: [Colors.transparent, Color(0xD9000000)],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (recipe.metaLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        recipe.metaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(top: 8, right: 8, child: _FavoriteButton(recipeId: recipe.id)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final int recipeId;

  const _FavoriteButton({required this.recipeId});

  @override
  Widget build(BuildContext context) {
    final favorites = FavoritesController.instance;
    return ListenableBuilder(
      listenable: favorites,
      builder: (context, _) {
        final active = favorites.isFavorite(recipeId);
        return Material(
          color: Colors.black.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => favorites.toggleFavorite(recipeId),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: AnimatedScale(
                scale: active ? 1.0 : 0.9,
                duration: Motion.medium,
                curve: Curves.easeOutBack,
                child: Icon(
                  active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 18,
                  color: active ? const Color(0xFFFF5A5F) : Colors.white,
                  semanticLabel: active ? 'Bỏ yêu thích' : 'Yêu thích',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Khung chờ cùng kích thước với [RecipeTileCard] (đặt trong Shimmer).
class RecipeTileSkeleton extends StatelessWidget {
  const RecipeTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    );
  }
}
