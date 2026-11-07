// =============================================================================
// MÀN HÌNH: TRANG CHỦ (tab "Trang Chủ")
// =============================================================================
//
// FILE NÀY CHỈ CHỨA GIAO DIỆN. Dữ liệu banner/danh mục và logic lọc nằm trong
// `home_controller.dart`; Dark Mode nằm trong `features/theme/theme_controller.dart`.
//
// FLOW UI
//   1. initState → tạo HomeController, lắng nghe thay đổi, bật timer banner.
//   2. Timer mỗi 4s → PageView trượt tới `nextBannerIndex`.
//   3. Chạm chip danh mục → `selectCategory` → lưới "Món ăn thịnh hành" lọc lại.
//   4. Thẻ CTA "Tủ lạnh" / "Gợi ý AI" → `onNavigateTab(index)` để
//      MainNavigationScreen chuyển tab.
//   5. Nút mặt trăng/mặt trời → ThemeController.toggleTheme().
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/recipe_card.dart';
import '../theme/theme_controller.dart';
import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  /// Callback để chuyển tab ở thanh điều hướng dưới (0: Home, 1: Gợi ý, 2: Túi Thần Kỳ, 3: Cá nhân).
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeController _controller = HomeController();
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _startBannerAutoSlide();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  /// Tự trượt banner: mỗi `bannerInterval` chuyển sang trang kế tiếp (quay vòng).
  void _startBannerAutoSlide() {
    _bannerTimer = Timer.periodic(HomeController.bannerInterval, (timer) {
      if (_bannerController.hasClients) {
        _bannerController.animateToPage(
          _controller.nextBannerIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final filteredRecipes = _controller.filteredRecipes;
    final fastRecipes = _controller.fastRecipes;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bếp Việt',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Food Tip & Smart Cooking',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: AppColors.primary,
            ),
            onPressed: () => setState(() => theme.toggleTheme()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar Shortcut
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: InkWell(
                onTap: () {
                  widget.onNavigateTab?.call(1); // Jump to Suggest tab
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Tìm công thức hoặc nguyên liệu tủ lạnh...',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textMutedDark
                              : AppColors.textMutedLight,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AI Vision',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Hero Coverflow Carousel
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _bannerController,
                itemCount: HomeController.heroBanners.length,
                onPageChanged: _controller.setBannerIndex,
                itemBuilder: (context, index) {
                  final banner = HomeController.heroBanners[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            banner['image']!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: AppColors.primaryDark,
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.75),
                                  Colors.black.withOpacity(0.35),
                                  Colors.transparent,
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    banner['tag']!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  banner['title']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  banner['subtitle']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // Carousel Indicator Dots
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(HomeController.heroBanners.length, (idx) {
                  final isActive = idx == _controller.currentBannerIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            // Kitchen Bag Teaser Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () => widget.onNavigateTab?.call(2), // Jump to Kitchen Bag
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.kitchen_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tủ lạnh hôm nay còn gì?',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Nhập nguyên liệu để Bếp Việt gợi ý món ngon tức thì',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Category Chips Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Danh mục món ngon',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: HomeController.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = HomeController.categories[index];
                  final isSelected = cat == _controller.selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : theme.isDarkMode
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                    backgroundColor: Theme.of(context).cardTheme.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : theme.isDarkMode
                                ? AppColors.dividerDark
                                : AppColors.dividerLight,
                      ),
                    ),
                    onSelected: (val) => _controller.selectCategory(cat),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Trending Recipes Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _controller.isAllCategory ? 'Món ăn thịnh hành' : 'Món: ${_controller.selectedCategory}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${filteredRecipes.length} món',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2-Column Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredRecipes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) {
                  return RecipeCard(
                    recipe: filteredRecipes[index],
                    onFavoriteToggled: () => setState(() {}),
                  );
                },
              ),
            ),

            const SizedBox(height: 28),

            // Fast Prep Recipes Row (< 25 mins)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
                  SizedBox(width: 6),
                  Text(
                    'Nấu nhanh gọn (Dưới 25 phút)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: fastRecipes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 180,
                    child: RecipeCard(
                      recipe: fastRecipes[index],
                      onFavoriteToggled: () => setState(() {}),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
