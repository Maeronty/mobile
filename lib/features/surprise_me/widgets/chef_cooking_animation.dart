// =============================================================================
// WIDGET: HOẠT ẢNH CHẢO XÓC THỨC ĂN (Frying Pan Sauté Animation)
// =============================================================================
//
// VAI TRÒ
//   Mô phỏng chiếc chảo line-art di chuyển trượt qua lại nhịp nhàng và xóc các
//   mẩu thức ăn (đỏ, vàng, xanh) tung lên tạo thành dải màu sống động, căn giữa
//   màn hình kèm đồng hồ đếm ngược 4 giây.
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ChefCookingAnimation extends StatefulWidget {
  final int countdownSeconds;
  final String message;

  const ChefCookingAnimation({
    super.key,
    required this.countdownSeconds,
    required this.message,
  });

  @override
  State<ChefCookingAnimation> createState() => _ChefCookingAnimationState();
}

class _ChefCookingAnimationState extends State<ChefCookingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hoạt ảnh chiếc chảo xóc thức ăn (Canvas 60fps)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(300, 160),
                    painter: _PanSautePainter(
                      progress: _controller.value,
                      isDark: isDark,
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Bộ đếm ngược 4s dạng vòng tròn tiến trình tinh tế
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: (5 - widget.countdownSeconds) / 4.0,
                      strokeWidth: 3.5,
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade200,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  Text(
                    '${widget.countdownSeconds}s',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Thông điệp trạng thái biến đổi từng giây
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  widget.message,
                  key: ValueKey<String>(widget.message),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Đang tìm kiếm món ngon bí mật cho bạn...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painter vẽ chiếc chảo line-art chính xác theo ảnh mẫu và đồ ăn xóc tung lên
class _PanSautePainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0
  final bool isDark;

  _PanSautePainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 15;

    // Chu kỳ chuyển động của chiếc chảo:
    // 0.0 -> 0.4: Chảo trượt sang trái rồi giật nhẹ hất thức ăn lên
    // 0.4 -> 0.7: Đồ ăn bay lên cao nhất theo parabol
    // 0.7 -> 1.0: Chảo đón đồ ăn rơi xuống và trượt về vị trí ban đầu
    final panSlideX = math.sin(progress * math.pi * 2) * 22.0;
    final panDipY = math.cos(progress * math.pi * 2) * 6.0;
    final panTiltAngle = -math.sin(progress * math.pi * 2) * 0.08;

    // Vị trí tâm của thân chảo
    final panCenterX = cx - 25 + panSlideX;
    final panCenterY = cy + panDipY;

    final strokeColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final panWidth = 140.0;
    final panHeight = 32.0;
    final handleLength = 80.0;
    final strokeWidth = 4.0;

    // -------------------------------------------------------------------------
    // 1. CÁC MẨU ĐỒ ĂN / DẢI MÀU XÓC TUNG LÊN (Food Items Floating)
    // -------------------------------------------------------------------------
    final foodItems = [
      // Mẩu ớt đỏ (Red pepper)
      _FoodParticle(
        color: const Color(0xFFDC2626),
        type: _FoodShape.curvedStick,
        baseOffsetX: -32,
        maxJumpHeight: 52,
        jumpOffsetProgress: 0.0,
      ),
      // Mẩu rau / ớt xanh (Green veg)
      _FoodParticle(
        color: const Color(0xFF16A34A),
        type: _FoodShape.square,
        baseOffsetX: -14,
        maxJumpHeight: 44,
        jumpOffsetProgress: 0.1,
      ),
      // Mẩu bắp / ớt chuông vàng (Yellow corn)
      _FoodParticle(
        color: const Color(0xFFF59E0B),
        type: _FoodShape.curvedStick,
        baseOffsetX: 12,
        maxJumpHeight: 48,
        jumpOffsetProgress: 0.2,
      ),
      // Mẩu cà rốt cam (Orange carrot)
      _FoodParticle(
        color: const Color(0xFFEA580C),
        type: _FoodShape.square,
        baseOffsetX: -2,
        maxJumpHeight: 56,
        jumpOffsetProgress: 0.15,
      ),
      // Mẩu gia vị hạt xanh đậm
      _FoodParticle(
        color: const Color(0xFF15803D),
        type: _FoodShape.dot,
        baseOffsetX: 28,
        maxJumpHeight: 38,
        jumpOffsetProgress: 0.05,
      ),
    ];

    for (final item in foodItems) {
      final t = (progress + item.jumpOffsetProgress) % 1.0;
      final jumpY = -4.0 * item.maxJumpHeight * t * (1.0 - t);
      // Khi rơi xuống chạm đáy chảo (jumpY = 0)
      final actualY = panCenterY - 12 + math.min(jumpY, 0.0);
      final actualX = panCenterX + item.baseOffsetX + math.sin(t * math.pi) * 6;

      canvas.save();
      canvas.translate(actualX, actualY);
      canvas.rotate(t * math.pi * 1.8);

      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      switch (item.type) {
        case _FoodShape.curvedStick:
          final path = Path()
            ..moveTo(-6, -2)
            ..quadraticBezierTo(0, -6, 6, -1)
            ..lineTo(5, 3)
            ..quadraticBezierTo(0, -2, -5, 2)
            ..close();
          canvas.drawPath(path, paint);
          break;

        case _FoodShape.square:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-4, -4, 8, 8),
              const Radius.circular(2),
            ),
            paint,
          );
          break;

        case _FoodShape.dot:
          canvas.drawCircle(Offset.zero, 3.5, paint);
          break;
      }

      canvas.restore();
    }

    // -------------------------------------------------------------------------
    // 2. CHIẾC CHẢO RÁN LINE-ART (Frying Pan Line-art)
    // -------------------------------------------------------------------------
    canvas.save();
    canvas.translate(panCenterX, panCenterY);
    canvas.rotate(panTiltAngle);

    final panStrokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final panFillPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : Colors.white
      ..style = PaintingStyle.fill;

    // Đường viền thân chảo (Lòng phẳng, mép dưới bo cong ở 2 góc, mép trên thẳng)
    final left = -panWidth / 2;
    final right = panWidth / 2;
    final top = -panHeight / 2;
    final bottom = panHeight / 2;
    const cornerRadius = 18.0;

    final panPath = Path()
      ..moveTo(left, top)
      ..lineTo(right, top)
      ..lineTo(right, bottom - cornerRadius)
      ..quadraticBezierTo(right, bottom, right - cornerRadius, bottom)
      ..lineTo(left + cornerRadius, bottom)
      ..quadraticBezierTo(left, bottom, left, bottom - cornerRadius)
      ..close();

    // Vẽ nền trong chảo
    canvas.drawPath(panPath, panFillPaint);
    // Vẽ viền chảo
    canvas.drawPath(panPath, panStrokePaint);

    // Mép trên chảo (đường thẳng ngăn cách lòng chảo)
    canvas.drawLine(
      Offset(left, top),
      Offset(right, top),
      panStrokePaint,
    );

    // Tay cầm thẳng nằm ngang kéo dài sang phải (Handle)
    final handlePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 0.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(right, top),
      Offset(right + handleLength, top),
      handlePaint,
    );

    // Đường nét highlight phản quang bên trong lòng chảo (như ảnh người dùng gửi)
    final highlightPaint = Paint()
      ..color = strokeColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Nét cong phản quang góc trái
    final leftHighlight = Path()
      ..moveTo(left + 6, top + 6)
      ..quadraticBezierTo(left + 6, bottom - 6, left + 20, bottom - 6);
    canvas.drawPath(leftHighlight, highlightPaint);

    // Nét cong phản quang góc phải
    final rightHighlight = Path()
      ..moveTo(right - 20, bottom - 6)
      ..quadraticBezierTo(right - 6, bottom - 6, right - 6, top + 6);
    canvas.drawPath(rightHighlight, highlightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PanSautePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

enum _FoodShape {
  curvedStick,
  square,
  dot,
}

class _FoodParticle {
  final Color color;
  final _FoodShape type;
  final double baseOffsetX;
  final double maxJumpHeight;
  final double jumpOffsetProgress;

  const _FoodParticle({
    required this.color,
    required this.type,
    required this.baseOffsetX,
    required this.maxJumpHeight,
    required this.jumpOffsetProgress,
  });
}
