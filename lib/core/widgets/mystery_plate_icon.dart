// =============================================================================
// WIDGET: ICON CHIẾC ĐĨA VÀ DẤU HỎI BÍ MẬT (Mystery Plate Icon)
// =============================================================================
//
// VAI TRÒ
//   Vẽ hình chiếu cạnh của chiếc đĩa (plate/dish) với dấu hỏi '?' lơ lửng
//   phía trên, tượng trưng cho món ăn bí mật của tính năng Surprise Me.
//   Đồng bộ 100% với phong cách line-art của dự án.
// =============================================================================

import 'package:flutter/material.dart';

class MysteryPlateIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const MysteryPlateIcon({
    super.key,
    this.size = 28,
    this.color = Colors.white,
    this.strokeWidth = 2.2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MysteryPlatePainter(
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _MysteryPlatePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _MysteryPlatePainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // -------------------------------------------------------------------------
    // 1. HÌNH CHIẾU CẠNH CỦA CHIẾC ĐĨA (Side-view Plate)
    // -------------------------------------------------------------------------
    // Đĩa nằm ở nửa dưới của khung vẽ: từ y = h * 0.62 đến h * 0.88
    final rimY = h * 0.68;
    final baseBottomY = h * 0.90;

    // Đường miệng/vành đĩa uốn nhẹ sang hai bên mép đĩa (Side rim)
    final plateRim = Path()
      ..moveTo(w * 0.10, rimY)
      ..quadraticBezierTo(w * 0.5, rimY + h * 0.04, w * 0.90, rimY);
    canvas.drawPath(plateRim, strokePaint);

    // Lòng và đáy đĩa: thành đĩa cong thu vào trong đế đĩa
    final plateBody = Path()
      ..moveTo(w * 0.14, rimY + h * 0.02)
      ..cubicTo(
        w * 0.18,
        h * 0.84,
        w * 0.32,
        baseBottomY,
        w * 0.42,
        baseBottomY,
      )
      ..lineTo(w * 0.58, baseBottomY)
      ..cubicTo(
        w * 0.68,
        baseBottomY,
        w * 0.82,
        h * 0.84,
        w * 0.86,
        rimY + h * 0.02,
      );
    canvas.drawPath(plateBody, strokePaint);

    // Đế chân đĩa nhỏ nằm dưới
    canvas.drawLine(
      Offset(w * 0.38, baseBottomY + strokeWidth * 0.8),
      Offset(w * 0.62, baseBottomY + strokeWidth * 0.8),
      strokePaint..strokeWidth = strokeWidth * 0.9,
    );

    // -------------------------------------------------------------------------
    // 2. DẤU HỎI '?' LƠ LỬNG TRÊN ĐĨA (Floating Question Mark)
    // -------------------------------------------------------------------------
    // Khôi phục strokeWidth chuẩn
    strokePaint.strokeWidth = strokeWidth;

    // Đường móc câu của dấu hỏi
    final qPath = Path()
      ..moveTo(w * 0.40, h * 0.16)
      ..cubicTo(w * 0.40, h * 0.06, w * 0.60, h * 0.06, w * 0.62, h * 0.20)
      ..cubicTo(w * 0.63, h * 0.32, w * 0.50, h * 0.34, w * 0.50, h * 0.44);
    canvas.drawPath(qPath, strokePaint);

    // Dấu chấm của dấu hỏi
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.53),
      strokeWidth * 0.75,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MysteryPlatePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
