// =============================================================================
// WIDGET: Ô "MẸO ĐẦU BẾP" (Cooking Mode)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị mẹo của bước hiện tại. Chỉ dùng khi bước đó có `tip`.
// =============================================================================

import 'package:flutter/material.dart';

class CookingChefTip extends StatelessWidget {
  final String tip;

  const CookingChefTip({super.key, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mẹo đầu bếp: $tip',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
