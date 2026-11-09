// =============================================================================
// WIDGET: MỘT CỘT THỐNG KÊ (thẻ hồ sơ)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị giá trị và nhãn: "Đã lưu", "Đã nấu", "Theo dõi".
// =============================================================================

import 'package:flutter/material.dart';

class ProfileStatColumn extends StatelessWidget {
  final String label;
  final String value;

  const ProfileStatColumn({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}
