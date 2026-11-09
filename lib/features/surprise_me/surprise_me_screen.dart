// =============================================================================
// SCREEN: SURPRISE ME — HÔM NAY ĂN GÌ? (Random Recipe Picker Screen)
// =============================================================================
//
// VAI TRÒ
//   Giao diện gồm 3 trạng thái:
//     1. Setup: Chọn filter (Thể loại, Thời gian, Độ khó) + đếm số món thỏa mãn.
//     2. Cooking: Hoạt ảnh Canvas đầu bếp quay lưng xào nấu trong 4 giây.
//     3. Result: Thẻ Hero Card món ăn trúng thưởng kèm các hành động Xem công
//        thức, Nấu ngay, Thả tim, Đổi món khác.
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/difficulty_stars.dart';
import '../../core/widgets/mystery_plate_icon.dart';
import '../cooking_mode/cooking_mode_screen.dart';
import '../favorites/favorites_controller.dart';
import '../recipe_detail/recipe_detail_screen.dart';
import 'surprise_me_controller.dart';
import 'widgets/chef_cooking_animation.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          child: _buildBody(context, isDark),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    switch (_controller.state) {
      case SurpriseState.setup:
        return _buildSetupView(context, isDark);
      case SurpriseState.cooking:
        return ChefCookingAnimation(
          countdownSeconds: _controller.countdownSeconds,
          message: _controller.cookingMessage,
        );
      case SurpriseState.result:
        return _buildResultView(context, isDark);
    }
  }

  // ===========================================================================
  // 1. GIAO DIỆN THIẾT LẬP BỘ LỌC (Setup View)
  // ===========================================================================
  Widget _buildSetupView(BuildContext context, bool isDark) {
    final matches = _controller.matchingRecipes;
    final totalCount = matches.length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner giới thiệu
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF374151), const Color(0xFF1F2937)]
                          : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.dividerDark
                          : const Color(0xFFFDBA74),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const MysteryPlateIcon(
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đầu bếp bí mật Bếp Việt',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Chọn thể loại bạn muốn hoặc để trống để random 100% tất cả món ngon!',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 1. Thể loại món ăn
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Thể loại món ăn',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _controller.selectedCategories.isEmpty
                          ? 'Tất cả'
                          : '${_controller.selectedCategories.length} đã chọn',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SurpriseMeController.availableCategories.map((cat) {
                    final isSelected =
                        _controller.selectedCategories.contains(cat);
                    return FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                      backgroundColor: Theme.of(context).cardTheme.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.dividerDark
                                  : AppColors.dividerLight),
                        ),
                      ),
                      onSelected: (_) => _controller.toggleCategory(cat),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // 2. Thời gian nấu
                const Text(
                  'Thời gian chế biến',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSingleFilterChip(
                      label: 'Nhanh (≤ 20p)',
                      isSelected: _controller.selectedTimeFilter == 1,
                      onTap: () => _controller.setTimeFilter(1),
                      isDark: isDark,
                    ),
                    _buildSingleFilterChip(
                      label: 'Vừa (21 - 40p)',
                      isSelected: _controller.selectedTimeFilter == 2,
                      onTap: () => _controller.setTimeFilter(2),
                      isDark: isDark,
                    ),
                    _buildSingleFilterChip(
                      label: 'Kỹ (> 40p)',
                      isSelected: _controller.selectedTimeFilter == 3,
                      onTap: () => _controller.setTimeFilter(3),
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 3. Độ khó
                const Text(
                  'Độ khó',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SurpriseMeController.availableDifficulties.map((diff) {
                    final isSelected = _controller.selectedDifficulty == diff;
                    return _buildSingleFilterChip(
                      label: diff,
                      isSelected: isSelected,
                      onTap: () => _controller.setDifficulty(diff),
                      isDark: isDark,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        // Thanh CTA dính đáy
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge đếm số món thỏa mãn
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    totalCount > 0
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 16,
                    color: totalCount > 0 ? AppColors.success : AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    totalCount > 0
                        ? '$totalCount món ăn sẵn sàng phục vụ'
                        : 'Không có món phù hợp, hãy nới lỏng bộ lọc nhé!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: totalCount > 0
                          ? (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight)
                          : AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: totalCount > 0 ? _controller.startCooking : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Đầu bếp bí mật, nấu ngay!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
        ),
      ),
      onSelected: (_) => onTap(),
    );
  }

  // ===========================================================================
  // 3. GIAO DIỆN KẾT QUẢ HERO CARD (Result View)
  // ===========================================================================
  Widget _buildResultView(BuildContext context, bool isDark) {
    final recipe = _controller.currentRecipe;
    if (recipe == null) {
      return Center(
        child: ElevatedButton(
          onPressed: _controller.backToSetup,
          child: const Text('Quay lại chọn tiêu chí'),
        ),
      );
    }

    final favorites = FavoritesController.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Banner chúc mừng
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✨', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Text(
                  'MÓN NGON BÍ MẬT DÀNH CHO BẠN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Thẻ Món Ăn Hero Card
          Container(
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
                      child: Image.asset(
                        recipe.imageAsset,
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
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
                              onPressed: () =>
                                  favorites.toggleFavorite(recipe.id),
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
                          _buildStatItem(
                            icon: Icons.access_time_rounded,
                            label: '${recipe.cookTimeMinutes} phút',
                            sublabel: 'Thời gian',
                            color: AppColors.primary,
                          ),
                          _buildStatItem(
                            icon: Icons.local_fire_department_rounded,
                            label: '${recipe.calories} kcal',
                            sublabel: 'Năng lượng',
                            color: Colors.deepOrange,
                          ),
                          _buildStatItem(
                            icon: Icons.people_outline_rounded,
                            label: '${recipe.servings} người',
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
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RecipeDetailScreen(
                                      recipeId: recipe.id,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.menu_book_rounded),
                              label: const Text('Xem công thức'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CookingModeScreen(
                                      recipe: recipe,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.play_circle_fill_rounded,
                                  color: Colors.white),
                              label: const Text('Nấu ngay'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
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
          ),

          const SizedBox(height: 20),

          // Nút Đổi món khác (Đầu bếp xào nấu lại 4s)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _controller.reroll,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text(
                'Đổi món khác (Xào nấu lại)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Nút quay lại chỉnh bộ lọc
          TextButton.icon(
            onPressed: _controller.backToSetup,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Tùy chỉnh lại bộ lọc'),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          sublabel,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
