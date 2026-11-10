// =============================================================================
// MÀN HÌNH: CHI TIẾT CÔNG THỨC
// =============================================================================
//
// FILE NÀY CHỈ GHÉP CÁC KHU VỰC GIAO DIỆN; từng khu vực nằm trong `widgets/`.
// Logic tải, khẩu phần & checklist nằm trong `recipe_detail_controller.dart`;
// trạng thái yêu thích nằm trong FavoritesController.
//
// FLOW UI
//   1. Mở từ thẻ món → có sẵn [preview] (ảnh, tên, danh mục) → ảnh bay tới
//      bằng Hero, hiện ngay; controller tải công thức đầy đủ theo id.
//   2. Đang tải → khung chờ shimmer cho phần thân.
//      Lỗi → thông báo + "Thử lại".
//   3. Tải xong → các khu vực (thông số, dinh dưỡng, nguyên liệu, các bước)
//      mờ dần trượt lên lần lượt.
//   4. Bấm [−]/[+] đổi khẩu phần; chạm dòng nguyên liệu để tick.
//   5. Nút dưới cùng → mở CookingModeScreen(recipe).
//
// LƯU Ý
//   Mở từ nơi không có preview (VD Surprise Me) → tên/ảnh hiện khi tải xong.
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/models/recipe.dart';
import '../../core/models/recipe_summary.dart';
import '../../core/motion/fade_slide_in.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/difficulty_stars.dart';
import '../cooking_mode/cooking_mode_screen.dart';
import '../favorites/favorites_controller.dart';
import 'recipe_detail_controller.dart';
import 'widgets/recipe_detail_app_bar.dart';
import 'widgets/recipe_ingredient_tile.dart';
import 'widgets/recipe_ingredients_header.dart';
import 'widgets/recipe_nutrition_section.dart';
import 'widgets/recipe_quick_stats.dart';
import 'widgets/recipe_start_cooking_bar.dart';
import 'widgets/recipe_step_card.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;

  /// Bản tóm tắt từ thẻ vừa bấm: hiện ngay ảnh + tên trong lúc tải.
  final RecipeSummary? preview;

  /// Tag Hero của ảnh, phải trùng với thẻ đã mở màn này.
  final String? heroTag;

  /// Cho test truyền controller dùng server giả.
  final RecipeDetailController? controller;

  const RecipeDetailScreen({super.key, required this.recipeId, this.preview, this.heroTag, this.controller});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final RecipeDetailController _controller =
      widget.controller ?? RecipeDetailController(recipeId: widget.recipeId);
  final _favorites = FavoritesController.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _favorites.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _favorites.removeListener(_onChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _openCookingMode(Recipe recipe) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CookingModeScreen(recipe: recipe)));
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _controller.recipe;
    final preview = widget.preview;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          RecipeDetailAppBar(
            title: recipe?.title ?? preview?.title ?? '',
            category: recipe?.category ?? preview?.category ?? '',
            imageUrl: preview?.image ?? recipe?.imageAsset ?? '',
            heroTag: widget.heroTag ?? 'detail-${widget.recipeId}',
            isFavorite: _favorites.isFavorite(widget.recipeId),
            onToggleFavorite: () => _favorites.toggleFavorite(widget.recipeId),
          ),
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: Motion.medium,
              switchInCurve: Motion.enter,
              child: recipe != null
                  ? _Body(key: const ValueKey('body'), recipe: recipe, controller: _controller)
                  : _controller.error != null
                      ? _ErrorView(key: const ValueKey('error'), message: _controller.error!, onRetry: _controller.load)
                      : const _BodySkeleton(key: ValueKey('loading')),
            ),
          ),
        ],
      ),
      bottomSheet: AnimatedSlide(
        offset: recipe == null ? const Offset(0, 1) : Offset.zero,
        duration: Motion.slow,
        curve: Motion.enter,
        child: recipe == null ? const SizedBox.shrink() : RecipeStartCookingBar(onPressed: () => _openCookingMode(recipe)),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Recipe recipe;
  final RecipeDetailController controller;

  const _Body({super.key, required this.recipe, required this.controller});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    var step = 0;
    Widget section(Widget child) => FadeSlideIn(delay: Motion.staggerDelay(step++), child: child);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section(RecipeQuickStats(recipe: recipe)),
          const SizedBox(height: 14),
          section(Text(
            recipe.description,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          )),
          const SizedBox(height: 22),
          section(RecipeNutritionSection(nutrition: recipe.nutrition, formatGrams: controller.formatScaledGrams)),
          const SizedBox(height: 26),
          section(RecipeIngredientsHeader(
            totalCount: recipe.ingredients.length,
            checkedCount: controller.checkedCount,
            servings: controller.servings,
            onDecrease: controller.canScale ? controller.decreaseServings : null,
            onIncrease: controller.canScale ? controller.increaseServings : null,
          )),
          const SizedBox(height: 8),
          section(Column(
            children: [
              for (var i = 0; i < recipe.ingredients.length; i++) ...[
                if (i > 0) Divider(height: 1, color: dark ? AppColors.dividerDark : AppColors.dividerLight),
                RecipeIngredientTile(
                  item: recipe.ingredients[i],
                  amountText: controller.formatScaledAmount(recipe.ingredients[i].amount),
                  isChecked: controller.isIngredientChecked(i),
                  onTap: () => controller.toggleIngredientCheck(i),
                ),
              ],
            ],
          )),
          const SizedBox(height: 28),
          section(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Các bước thực hiện', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DifficultyStars(difficulty: recipe.difficulty),
            ],
          )),
          const SizedBox(height: 14),
          section(Column(children: [for (final s in recipe.instructions) RecipeStepCard(step: s)])),
        ],
      ),
    );
  }
}

class _BodySkeleton extends StatelessWidget {
  const _BodySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: SkeletonBox(height: 64)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 64)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 64)),
            ]),
            SizedBox(height: 20),
            SkeletonBox(height: 14, width: 220),
            SizedBox(height: 8),
            SkeletonBox(height: 14),
            SizedBox(height: 26),
            SkeletonBox(height: 20, width: 180),
            SizedBox(height: 14),
            SkeletonBox(height: 44),
            SizedBox(height: 8),
            SkeletonBox(height: 44),
            SizedBox(height: 8),
            SkeletonBox(height: 44),
            SizedBox(height: 8),
            SkeletonBox(height: 44),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
        ],
      ),
    );
  }
}
