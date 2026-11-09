// =============================================================================
// WIDGET: CAROUSEL BANNER (trang chủ)
// =============================================================================
//
// FLOW
//   1. HomeScreen giữ PageController + timer tự trượt, truyền controller vào đây.
//   2. Trang đổi (vuốt tay hoặc timer) → `onPageChanged` → HomeController ghi
//      nhận vị trí để chấm chỉ báo cập nhật.
// =============================================================================

import 'package:flutter/material.dart';
import 'home_banner_card.dart';

class HomeHeroCarousel extends StatelessWidget {
  final PageController controller;
  final List<Map<String, String>> banners;
  final ValueChanged<int> onPageChanged;

  const HomeHeroCarousel({
    super.key,
    required this.controller,
    required this.banners,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: controller,
        itemCount: banners.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) => HomeBannerCard(banner: banners[index]),
      ),
    );
  }
}
