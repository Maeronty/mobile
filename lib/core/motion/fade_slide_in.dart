// =============================================================================
// MOTION: XUẤT HIỆN MỜ DẦN + TRƯỢT NHẸ LÊN (FadeSlideIn)
// =============================================================================
//
// FLOW
//   1. Widget được dựng lần đầu → chờ [delay] (để các thẻ hiện lần lượt).
//   2. Opacity 0 → 1 và dịch từ [offsetY] px → 0 trong [Motion.medium].
//   3. `animate = false` (VD thẻ đã từng hiện, cuộn quay lại) hoặc máy bật
//      "Giảm chuyển động" → hiện ngay, không hiệu ứng.
//
// LƯU Ý
//   Dùng FadeTransition + Transform (không đổi layout) nên rẻ khi cuộn.
// =============================================================================

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'motion.dart';

class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offsetY;
  final bool animate;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 16,
    this.animate = true,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.medium);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Motion.enter);
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    if (!widget.animate) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      // Timer (không phải Future.delayed) để huỷ được khi thẻ bị cuộn khỏi màn.
      _delay = Timer(widget.delay, _controller.forward);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offsetY),
          child: child,
        ),
      ),
    );
  }
}
