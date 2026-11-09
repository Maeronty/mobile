// =============================================================================
// SCREEN: SURPRISE ME — HÔM NAY ĂN GÌ? (Random Recipe Picker Screen)
// =============================================================================
//
// VAI TRÒ
//   Chọn giao diện theo trạng thái của controller; từng giao diện nằm trong
//   `widgets/`:
//     1. Setup: Chọn filter (Thể loại, Thời gian, Độ khó) + đếm số món thỏa mãn.
//     2. Cooking: Hoạt ảnh Canvas đầu bếp quay lưng xào nấu trong 4 giây.
//     3. Result: Thẻ Hero Card món ăn trúng thưởng kèm các hành động Xem công
//        thức, Nấu ngay, Thả tim, Đổi món khác.
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/models/recipe.dart';
import '../../core/theme/app_colors.dart';
import '../cooking_mode/cooking_mode_screen.dart';
import '../recipe_detail/recipe_detail_screen.dart';
import 'surprise_me_controller.dart';
import 'widgets/chef_cooking_animation.dart';
import 'widgets/surprise_result_view.dart';
import 'widgets/surprise_setup_view.dart';

class SurpriseMeScreen extends StatefulWidget {
  const SurpriseMeScreen({super.key});

  @override
  State<SurpriseMeScreen> createState() => _SurpriseMeScreenState();
}

class _SurpriseMeScreenState extends State<SurpriseMeScreen> {
  late final SurpriseMeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SurpriseMeController();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _openRecipeDetail(Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
      ),
    );
  }

  void _openCookingMode(Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CookingModeScreen(recipe: recipe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hôm Nay Ăn Gì?'),
        centerTitle: true,
        actions: [
          if (_controller.state == SurpriseState.setup &&
              _controller.hasActiveFilter)
            TextButton(
              onPressed: _controller.clearAllFilters,
              child: const Text(
                'Đặt lại',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_controller.state) {
      case SurpriseState.setup:
        return SurpriseSetupView(controller: _controller);
      case SurpriseState.cooking:
        return ChefCookingAnimation(
          countdownSeconds: _controller.countdownSeconds,
          message: _controller.cookingMessage,
        );
      case SurpriseState.result:
        return SurpriseResultView(
          controller: _controller,
          onViewRecipe: _openRecipeDetail,
          onCookNow: _openCookingMode,
        );
    }
  }
}
