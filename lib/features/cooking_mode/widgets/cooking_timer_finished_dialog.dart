// =============================================================================
// WIDGET: DIALOG "HẾT GIỜ" (Cooking Mode)
// =============================================================================
//
// FLOW
//   Đồng hồ về 0 → CookingModeController gọi callback → màn hình mở dialog này.
//   Bấm "Đã hiểu" → đóng dialog và ở lại bước hiện tại.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CookingTimerFinishedDialog extends StatelessWidget {
  final int stepNumber;

  const CookingTimerFinishedDialog({super.key, required this.stepNumber});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.alarm_on_rounded, color: AppColors.accent, size: 28),
          SizedBox(width: 8),
          Text('Hết giờ!'),
        ],
      ),
      content: Text('Đã hoàn thành thời gian cho bước $stepNumber. Bạn có thể chuyển sang bước tiếp theo!'),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đã hiểu'),
        ),
      ],
    );
  }
}
