// =============================================================================
// MOTION: KHUNG XƯƠNG KHI ĐANG TẢI (Shimmer + SkeletonBox)
// =============================================================================
//
// CÁCH DÙNG
//   Shimmer(child: Column(children: [SkeletonBox(height: 120), ...]))
//
// FLOW
//   - Một Shimmer chỉ có MỘT AnimationController cho mọi SkeletonBox bên
//     trong (không phải mỗi ô một controller) → nhẹ khi có nhiều ô.
//   - Dải sáng chạy chéo từ trái qua phải mỗi 1,2 giây (ShaderMask).
//   - "Giảm chuyển động" → khung đứng yên, không có dải sáng.
// =============================================================================

import 'package:flutter/material.dart';

import 'motion.dart';

class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF263244) : const Color(0xFFE7ECF2);
    final highlight = dark ? const Color(0xFF334155) : const Color(0xFFF6F8FB);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value * 2 - 0.5; // -0.5 → 1.5: dải sáng đi hết chiều ngang
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, highlight, base],
            stops: [(t - 0.3).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.3).clamp(0.0, 1.0)],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Một ô xám bo góc làm khung chờ. Đặt bên trong [Shimmer] để có dải sáng.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
    );
  }
}
