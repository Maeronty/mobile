// =============================================================================
// WIDGET: LƯỚI MÓN CUỘN VÔ HẠN (Home) — các sliver của phần danh sách
// =============================================================================
//
// GỒM
//   1. HomeRecipeGrid  : SliverGrid 2 cột, dựng thẻ LƯỜI (chỉ thẻ sắp hiện
//      trên màn hình mới được dựng) → hàng nghìn món vẫn nhẹ.
//      Thẻ mới xuất hiện lần đầu → mờ dần + trượt lên, lệch nhau ~45 ms theo vị
//      trí trong trang (stagger). Mỗi thẻ bọc RepaintBoundary để khi một thẻ
//      đổi (ảnh tải xong, tim) không vẽ lại cả lưới.
//   2. HomeGridFooter  : đang tải → 2 hàng thẻ khung chờ (shimmer);
//      lỗi → thông báo + nút "Thử lại"; hết món → dòng kết thúc.
//   3. Bố cục cột: màn hẹp 2 cột, ≥ 700 px 3 cột, ≥ 1000 px 4 cột.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/models/recipe_summary.dart';
import '../../../core/motion/fade_slide_in.dart';
import '../../../core/motion/motion.dart';
import '../../../core/motion/shimmer.dart';
import '../../../core/widgets/recipe_tile_card.dart';

SliverGridDelegate homeGridDelegate(double width) => SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: width >= 1000 ? 4 : (width >= 700 ? 3 : 2),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.74,
    );

class HomeRecipeGrid extends StatelessWidget {
  final List<RecipeSummary> items;
  final bool Function(int id) shouldAnimate;
  final int pageSize;

  const HomeRecipeGrid({super.key, required this.items, required this.shouldAnimate, required this.pageSize});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid(
          gridDelegate: homeGridDelegate(constraints.crossAxisExtent),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final recipe = items[i];
              return RepaintBoundary(
                child: FadeSlideIn(
                  key: ValueKey(recipe.id),
                  animate: shouldAnimate(recipe.id),
                  delay: Motion.staggerDelay(i % pageSize),
                  child: RecipeTileCard(recipe: recipe, heroTag: 'feed-${recipe.id}'),
                ),
              );
            },
            childCount: items.length,
            findChildIndexCallback: (key) {
              final id = (key as ValueKey<int>).value;
              final index = items.indexWhere((r) => r.id == id);
              return index < 0 ? null : index;
            },
          ),
        ),
      ),
    );
  }
}

class HomeGridFooter extends StatelessWidget {
  final bool loading;
  final bool hasMore;
  final String? error;
  final int total;
  final bool fillViewport;
  final VoidCallback onRetry;

  const HomeGridFooter({
    this.fillViewport = false,
    super.key,
    required this.loading,
    required this.hasMore,
    required this.error,
    required this.total,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              const Icon(Icons.wifi_off_rounded, size: 36, color: Colors.grey),
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (loading) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final delegate = homeGridDelegate(constraints.crossAxisExtent) as SliverGridDelegateWithFixedCrossAxisCount;
            return SliverToBoxAdapter(
              child: Shimmer(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: delegate,
                  itemCount: delegate.crossAxisCount * (fillViewport ? 4 : 2),
                  itemBuilder: (_, __) => const RecipeTileSkeleton(),
                ),
              ),
            );
          },
        ),
      );
    }
    if (!hasMore && total > 0) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Text(
            'Bạn đã xem hết $total món 🎉',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    if (!hasMore && total == 0) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Chưa có món nào trong danh mục này.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox(height: 24));
  }
}
