// =============================================================================
// WIDGET: MỘT Ô CHỈ SỐ DINH DƯỠNG (Chi tiết công thức)
// =============================================================================
//
// LƯU Ý
//   Trả về Expanded nên phải đặt trực tiếp trong Row/Column.
// =============================================================================

import 'package:flutter/material.dart';

class RecipeNutritionBadge extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const RecipeNutritionBadge({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.85)),
            ),
          ],
        ),
      ),
    );
  }
}
