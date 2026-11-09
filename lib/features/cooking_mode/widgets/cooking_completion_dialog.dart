// =============================================================================
// WIDGET: DIALOG CHÚC MỪNG HOÀN TẤT MÓN ĂN (Cooking Mode)
// =============================================================================
//
// FLOW
//   Bấm "Hoàn tất nấu ăn" → đóng dialog → thoát luôn màn hình Cooking Mode
//   (gọi Navigator.pop 2 lần).
// =============================================================================

import 'package:flutter/material.dart';

class CookingCompletionDialog extends StatelessWidget {
  final String recipeTitle;

  const CookingCompletionDialog({super.key, required this.recipeTitle});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.celebration_rounded, color: Colors.amber, size: 30),
          SizedBox(width: 8),
          Text('Chúc mừng!'),
        ],
      ),
      content: Text('Bạn đã hoàn tất món ăn "$recipeTitle". Chúc bạn và gia đình có một bữa ăn thật ngon miệng!'),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pop(context); // Exit cooking mode
          },
          child: const Text('Hoàn tất nấu ăn'),
        ),
      ],
    );
  }
}
