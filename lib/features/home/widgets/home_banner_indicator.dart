// =============================================================================
// WIDGET: CHẤM CHỈ BÁO VỊ TRÍ BANNER (trang chủ)
// =============================================================================
//
// VAI TRÒ
//   Vẽ một hàng chấm; chấm ứng với `currentIndex` kéo dài và đổi sang màu chính.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HomeBannerIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;

  const HomeBannerIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (idx) {
          final isActive = idx == currentIndex;
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
    );
  }
}
