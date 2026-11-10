// =============================================================================
// MOTION: CHUYỂN SANG MÀN CHI TIẾT MÓN (recipeRoute)
// =============================================================================
//
// FLOW
//   - Ảnh món bay từ thẻ lên đầu màn chi tiết bằng Hero (tag do nơi gọi đặt,
//     xem `RecipeTileCard`).
//   - Phần còn lại của màn chi tiết mờ dần vào + phóng nhẹ 0.98 → 1.0
//     trong 420 ms; khi quay lại thì ngược lại, nhanh hơn (280 ms).
//   - "Giảm chuyển động" → chuyển ngay, không hiệu ứng.
// =============================================================================

import 'package:flutter/material.dart';

import 'motion.dart';

Route<T> recipeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: Motion.slow,
    reverseTransitionDuration: Motion.medium,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (Motion.reduced(context)) return child;
      final curved = CurvedAnimation(parent: animation, curve: Motion.enter, reverseCurve: Motion.exit);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(curved), child: child),
      );
    },
  );
}
