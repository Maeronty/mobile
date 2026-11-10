// =============================================================================
// MOTION: PHẢN HỒI KHI NHẤN (Pressable)
// =============================================================================
//
// FLOW
//   Ngón tay chạm xuống → thu nhỏ còn [pressedScale] trong 150 ms.
//   Nhấc lên / huỷ → trở lại 1.0. Nhấc lên trong vùng → gọi [onTap].
//   Dùng cho thẻ món, banner, nút nhanh: cho cảm giác "bấm được" ngay lập tức,
//   kể cả trước khi màn hình mới mở xong.
// =============================================================================

import 'package:flutter/widgets.dart';

import 'motion.dart';

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const Pressable({super.key, required this.child, this.onTap, this.pressedScale = 0.97});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed && !Motion.reduced(context) ? widget.pressedScale : 1,
        duration: Motion.fast,
        curve: Motion.enter,
        child: widget.child,
      ),
    );
  }
}
