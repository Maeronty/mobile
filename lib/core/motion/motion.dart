// =============================================================================
// MOTION — Thông số chuyển động dùng chung toàn app
// =============================================================================
//
// NGUYÊN TẮC
//   - Ngắn và nhất quán: 150 ms (phản hồi chạm), 280 ms (xuất hiện / chuyển
//     trạng thái), 420 ms (chuyển màn hình, banner).
//   - Đường cong "easeOutCubic": vào nhanh, dừng êm — cảm giác nhẹ, không nảy.
//   - Chỉ animate opacity / transform (không đổi layout) → không gây giật.
//   - Tôn trọng cài đặt "Giảm chuyển động" của hệ điều hành / trình duyệt:
//     `Motion.reduced(context)` = true thì bỏ hiệu ứng, hiện ngay kết quả.
// =============================================================================

import 'package:flutter/widgets.dart';

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOutCubic;

  /// Độ trễ giữa các phần tử xuất hiện lần lượt (stagger), tối đa [maxStaggerSteps] bước.
  static const Duration stagger = Duration(milliseconds: 45);
  static const int maxStaggerSteps = 8;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration staggerDelay(int step) => stagger * step.clamp(0, maxStaggerSteps);
}
