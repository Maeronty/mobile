// =============================================================================
// MÀN HÌNH: TRANG CHỦ (tab "Trang Chủ") — phong cách tạp chí ẩm thực
// =============================================================================
//
// FILE NÀY CHỈ GHÉP CÁC KHU VỰC GIAO DIỆN; từng khu vực nằm trong `widgets/`.
// Dữ liệu + phân trang nằm trong `home_controller.dart`.
//
// BỐ CỤC (một CustomScrollView duy nhất → cuộn mượt, dựng lười)
//   1. App bar nổi: logo, nút tìm kiếm, nút sáng/tối. Cuộn xuống thì ẩn, kéo
//      lên một chút là hiện lại ngay (floating + snap).
//   2. Lời chào "Hôm nay nấu gì?" (+ báo nhẹ nếu đang dùng dữ liệu ngoại tuyến).
//   3. Banner món nổi bật (vuốt ngang, tự chạy).
//   4. Hai phím tắt: Tủ lạnh / Surprise Me.
//   5. Thanh danh mục DÍNH trên đầu khi cuộn.
//   6. Lưới món 2 cột, tự tải trang kế khi gần cuối.
//
// FLOW UI
//   - Mở màn → controller.init(): banner, danh mục, trang 1 (khung chờ shimmer).
//   - Cuộn tới khi còn < 900 px là chạm cuối → controller.loadMore().
//   - Chọn danh mục → nếu đã cuộn quá thanh danh mục thì cuộn mượt về ngay
//     dưới thanh, rồi lưới mới hiện lần lượt.
//   - Kéo xuống ở đầu trang → làm mới (thử lại server nếu đang ngoại tuyến).
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/motion/fade_slide_in.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../surprise_me/surprise_me_screen.dart';
import 'home_controller.dart';
import 'widgets/home_brand_title.dart';
import 'widgets/home_category_bar.dart';
import 'widgets/home_featured_carousel.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_recipe_grid.dart';
import 'widgets/home_theme_toggle_button.dart';

class HomeScreen extends StatefulWidget {
  /// Chuyển tab ở thanh điều hướng dưới (0: Home, 1: Gợi ý, 2: Túi Thần Kỳ, 3: Cá nhân).
  final Function(int)? onNavigateTab;

  /// Cho test truyền controller dùng nguồn dữ liệu giả.
  final HomeController? controller;

  const HomeScreen({super.key, this.onNavigateTab, this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller = widget.controller ?? HomeController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _topKey = GlobalKey();

  static const double _loadMoreThreshold = 900;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _scroll.addListener(_maybeLoadMore);
    _controller.init().then((_) => _fillViewport());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _controller.removeListener(_onChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < _loadMoreThreshold) {
      _controller.loadMore();
    }
  }

  /// Màn hình cao (desktop/tablet) có thể chưa đủ món để cuộn → tải thêm.
  void _fillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent < _loadMoreThreshold && _controller.hasMore) {
        _controller.loadMore().then((_) => _fillViewport());
      }
    });
  }

  Future<void> _selectCategory(String? category) async {
    // Đã cuộn qua thanh danh mục → đưa lưới về ngay dưới thanh (thanh vẫn dính).
    final topHeight = _topKey.currentContext?.size?.height;
    if (topHeight != null && _scroll.hasClients && _scroll.offset > topHeight) {
      final reduced = Motion.reduced(context);
      if (reduced) {
        _scroll.jumpTo(topHeight);
      } else {
        _scroll.animateTo(topHeight, duration: Motion.slow, curve: Motion.standard);
      }
    }
    await _controller.selectCategory(category);
    _fillViewport();
  }

  void _openSurpriseMe() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SurpriseMeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await c.refresh();
          _fillViewport();
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          cacheExtent: 600,
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              titleSpacing: 16,
              title: const HomeBrandTitle(),
              actions: [
                IconButton(
                  tooltip: 'Tìm món',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => widget.onNavigateTab?.call(1),
                ),
                const HomeThemeToggleButton(),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                key: _topKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeSlideIn(child: _Greeting(offline: c.isOffline)),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    child: c.featured.isEmpty
                        ? const Shimmer(child: HomeFeaturedSkeleton())
                        : HomeFeaturedCarousel(key: const ValueKey('featured'), items: c.featured),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delay: Motion.stagger * 2,
                    child: HomeQuickActions(
                      onOpenPantry: () => widget.onNavigateTab?.call(2),
                      onOpenSurprise: _openSurpriseMe,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: HomeCategoryBarDelegate(
                categories: c.categories,
                allCount: c.allCount,
                selected: c.selectedCategory,
                onSelected: _selectCategory,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: AnimatedSwitcher(
                  duration: Motion.medium,
                  child: Row(
                    key: ValueKey('${c.sectionTitle}-${c.total}'),
                    children: [
                      Flexible(
                        child: Text(
                          c.sectionTitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (c.total > 0) Text('${c.total} món', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            HomeRecipeGrid(items: c.items, shouldAnimate: c.shouldAnimate, pageSize: HomeController.pageSize),
            HomeGridFooter(
              loading: c.isLoading,
              hasMore: c.hasMore,
              error: c.error,
              total: c.total,
              onRetry: () => c.retry().then((_) => _fillViewport()),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final bool offline;

  const _Greeting({required this.offline});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final hello = hour < 11 ? 'Chào buổi sáng' : (hour < 14 ? 'Chào buổi trưa' : (hour < 18 ? 'Chào buổi chiều' : 'Chào buổi tối'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$hello 👋', style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 2),
          const Text('Hôm nay nấu gì?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15)),
          if (offline) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Không kết nối được máy chủ — đang dùng dữ liệu có sẵn. Kéo xuống để thử lại.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
