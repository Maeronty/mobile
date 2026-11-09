// =============================================================================
// WIDGET: ĐỒNG HỒ ĐẾM NGƯỢC (Cooking Mode)
// =============================================================================
//
// FLOW
//   Nút Play/Pause → `onToggle`; nút làm mới → `onReset`.
//   Logic đếm ngược nằm trong CookingModeController, widget chỉ hiển thị.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CookingTimerPanel extends StatelessWidget {
  final String formattedTime;
  final bool isRunning;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  const CookingTimerPanel({
    super.key,
    required this.formattedTime,
    required this.isRunning,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
                SizedBox(width: 6),
                Text(
                  'Đồng hồ đếm ngược',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formattedTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: isRunning ? AppColors.accent : AppColors.primary,
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                  onPressed: onToggle,
                ),
                const SizedBox(width: 16),
                IconButton.outlined(
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: onReset,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
