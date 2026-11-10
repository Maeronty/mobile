// =============================================================================
// MÀN HÌNH: TRANG CHỦ (tab "Trang Chủ")
// =============================================================================
//
// FILE NÀY CHỈ GHÉP CÁC KHU VỰC GIAO DIỆN; từng khu vực nằm trong `widgets/`.
// Dữ liệu banner/danh mục và logic lọc nằm trong `home_controller.dart`;
// Dark Mode nằm trong `features/theme/theme_controller.dart`.
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

import '../../core/widgets/mystery_plate_icon.dart';
import '../surprise_me/surprise_me_screen.dart';
import 'home_controller.dart';
import 'widgets/home_action_card.dart';
import 'widgets/home_banner_indicator.dart';
import 'widgets/home_brand_title.dart';
import 'widgets/home_category_section.dart';
import 'widgets/home_fast_recipes_section.dart';
import 'widgets/home_hero_carousel.dart';
import 'widgets/home_search_shortcut.dart';
import 'widgets/home_theme_toggle_button.dart';
import 'widgets/home_trending_section.dart';

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

  void _openSurpriseMe() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SurpriseMeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const HomeBrandTitle(),
        actions: const [HomeThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSearchShortcut(
              onTap: () => widget.onNavigateTab?.call(1), // Jump to Suggest tab
            ),

            HomeHeroCarousel(
              controller: _bannerController,
              banners: HomeController.heroBanners,
              onPageChanged: _controller.setBannerIndex,
            ),

            const SizedBox(height: 10),

            HomeBannerIndicator(
              count: HomeController.heroBanners.length,
              currentIndex: _controller.currentBannerIndex,
            ),

            const SizedBox(height: 20),

            HomeActionCard(
              gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
              icon: const Icon(
                Icons.kitchen_rounded,
                color: Colors.white,
                size: 28,
              ),
              title: 'Tủ lạnh hôm nay còn gì?',
              subtitle: 'Nhập nguyên liệu để Bếp Việt gợi ý món ngon tức thì',
              onTap: () => widget.onNavigateTab?.call(2), // Jump to Kitchen Bag
            ),

            const SizedBox(height: 12),

            HomeActionCard(
              gradientColors: const [Color(0xFFEA580C), Color(0xFFF97316)],
              icon: const MysteryPlateIcon(color: Colors.white, size: 28),
              title: 'Hôm nay ăn gì? • Surprise Me',
              subtitle: 'Chọn thể loại hoặc để đầu bếp bí mật chọn ngẫu nhiên món ngon!',
              onTap: _openSurpriseMe,
            ),

            const SizedBox(height: 24),

            HomeCategorySection(
              categories: HomeController.categories,
              selectedCategory: _controller.selectedCategory,
              onSelected: _controller.selectCategory,
            ),

            const SizedBox(height: 24),

            HomeTrendingSection(
              title: _controller.isAllCategory
                  ? 'Món ăn thịnh hành'
                  : 'Món: ${_controller.selectedCategory}',
              recipes: _controller.visibleRecipes,
              totalCount: _controller.filteredRecipes.length,
              onShowMore: _controller.hasMore ? _controller.showMore : null,
              onFavoriteToggled: () => setState(() {}),
            ),

            const SizedBox(height: 28),

            if (_controller.fastRecipes.isNotEmpty)
              HomeFastRecipesSection(
                recipes: _controller.fastRecipes,
                onFavoriteToggled: () => setState(() {}),
              ),
          ],
        ),
      ),
    );
  }
}
