// =============================================================================
// MÀN HÌNH: CHI TIẾT CÔNG THỨC
// =============================================================================
//
// FILE NÀY CHỈ GHÉP CÁC KHU VỰC GIAO DIỆN; từng khu vực nằm trong `widgets/`.
// Logic khẩu phần & checklist nằm trong `recipe_detail_controller.dart`; trạng
// thái yêu thích nằm trong FavoritesController.
//
// FLOW UI
//   1. initState → tạo RecipeDetailController(recipeId) và lắng nghe.
//   2. AppBar: nút chia sẻ (SnackBar demo) & nút trái tim (toggleFavorite).
//   3. Khối dinh dưỡng + danh sách nguyên liệu hiển thị số đã nhân hệ số
//      khẩu phần; bấm [−]/[+] để đổi khẩu phần, chạm dòng để tick nguyên liệu.
//   4. Nút dưới cùng → mở CookingModeScreen(recipe).
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/models/recipe.dart';
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
  final Recipe? recipe;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    this.recipe,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final RecipeDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RecipeDetailController(
      recipeId: widget.recipeId,
      initialRecipe: widget.recipe,
    );
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  void _openCookingMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CookingModeScreen(recipe: _controller.recipe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = FavoritesController.instance;
    final recipe = _controller.recipe;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          RecipeDetailAppBar(
            recipe: recipe,
            isFavorite: favorites.isFavorite(recipe.id),
            onToggleFavorite: () {
              setState(() {
                favorites.toggleFavorite(recipe.id);
              });
            },
          ),

          // Body Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RecipeQuickStats(recipe: recipe),

                  const SizedBox(height: 16),

                  // Description
                  Text(
                    recipe.description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),

                  const SizedBox(height: 24),

                  RecipeNutritionSection(
                    nutrition: recipe.nutrition,
                    formatGrams: _controller.formatScaledGrams,
                  ),

                  const SizedBox(height: 28),

                  RecipeIngredientsHeader(
                    totalCount: recipe.ingredients.length,
                    checkedCount: _controller.checkedCount,
                    servings: _controller.servings,
                    onDecrease: _controller.decreaseServings,
                    onIncrease: _controller.increaseServings,
                  ),

                  const SizedBox(height: 12),

                  // Ingredients List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recipe.ingredients.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = recipe.ingredients[index];
                      return RecipeIngredientTile(
                        item: item,
                        amountText: _controller.formatScaledAmount(item.amount),
                        isChecked: _controller.isIngredientChecked(index),
                        onTap: () => _controller.toggleIngredientCheck(index),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Step-by-Step Instructions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Các bước thực hiện',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      DifficultyStars(difficulty: recipe.difficulty),
                    ],
                  ),

                  const SizedBox(height: 16),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recipe.instructions.length,
                    itemBuilder: (context, index) =>
                        RecipeStepCard(step: recipe.instructions[index]),
                  ),

                  const SizedBox(height: 80), // Padding for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: RecipeStartCookingBar(onPressed: _openCookingMode),
    );
  }
}
