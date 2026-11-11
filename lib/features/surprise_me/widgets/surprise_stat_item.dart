// =============================================================================
// WIDGET: MỘT Ô THÔNG SỐ NHANH (thẻ kết quả Surprise Me)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị icon, giá trị và nhãn phụ: thời gian, năng lượng.
// =============================================================================

import 'package:flutter/material.dart';

class SurpriseStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const SurpriseStatItem({
    super.key,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          sublabel,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
