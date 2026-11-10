// =============================================================================
// WIDGET: BANNER MÓN NỔI BẬT (Home) — ảnh lớn, vuốt ngang, tự chạy
// =============================================================================
//
// MOTION
//   - Trang ở giữa to 100%, trang hai bên thu còn 92% và mờ bớt → khi vuốt,
//     thẻ "nổi" dần lên (tính theo vị trí PageController, không dùng setState).
//   - Ảnh dịch ngược chiều vuốt một chút (parallax) → có chiều sâu.
//   - Tự chuyển trang mỗi [HomeController.bannerInterval]; người dùng chạm /
//     kéo thì dừng tự chạy, thả tay ra mới chạy lại.
//   - Chấm chỉ báo: chấm đang chọn dài ra (AnimatedContainer).
//   - "Giảm chuyển động" → không tự chạy, không thu phóng.
//
// FLOW
//   Nhấn banner → mở chi tiết món (Hero tag `featured-<id>`).
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/recipe_summary.dart';
import '../../../core/motion/motion.dart';
import '../../../core/motion/pressable.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/recipe_tile_card.dart';
import '../home_controller.dart';

class HomeFeaturedCarousel extends StatefulWidget {
  final List<RecipeSummary> items;

  const HomeFeaturedCarousel({super.key, required this.items});

  @override
  State<HomeFeaturedCarousel> createState() => _HomeFeaturedCarouselState();
}

class _HomeFeaturedCarouselState extends State<HomeFeaturedCarousel> {
  final PageController _pages = PageController(viewportFraction: 0.88);
  Timer? _timer;
  int _index = 0;
  bool _userInteracting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (Motion.reduced(context)) return;
    _timer = Timer.periodic(HomeController.bannerInterval, (_) {
      if (_userInteracting || !_pages.hasClients || widget.items.length < 2) return;
      _pages.animateToPage((_index + 1) % widget.items.length, duration: Motion.slow * 1.5, curve: Motion.standard);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification && n.dragDetails != null) _userInteracting = true;
              if (n is ScrollEndNotification) _userInteracting = false;
              return false;
            },
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => AnimatedBuilder(
                animation: _pages,
                builder: (context, child) {
                  final page = _pages.hasClients && _pages.position.haveDimensions
                      ? _pages.page ?? _index.toDouble()
                      : _index.toDouble();
                  final distance = (page - i).clamp(-1.0, 1.0);
                  final scale = reduced ? 1.0 : 1 - distance.abs() * 0.08;
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: reduced ? 1 : 1 - distance.abs() * 0.35,
                      child: _FeaturedCard(recipe: widget.items[i], parallax: reduced ? 0 : distance),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.items.length; i++)
              AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.enter,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _index ? AppColors.primary : AppColors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final RecipeSummary recipe;
  final double parallax;

  const _FeaturedCard({required this.recipe, required this.parallax});

  @override
  Widget build(BuildContext context) {
    final tag = 'featured-${recipe.id}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Pressable(
        onTap: () => RecipeTileCard.open(context, recipe, tag),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: tag,
                child: AppNetworkImage(url: recipe.image, alignment: Alignment(parallax * 0.6, 0)),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1],
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        recipe.category.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.2, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khung chờ cho banner khi chưa có dữ liệu.
class HomeFeaturedSkeleton extends StatelessWidget {
  const HomeFeaturedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        height: 220,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
