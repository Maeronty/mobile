// =============================================================================
// WIDGET: THANH TIẾN ĐỘ NẤU ĂN (Cooking Mode)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị "Bước x / y", phần trăm hoàn thành và thanh tiến độ.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CookingProgressHeader extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;

  /// Tiến độ từ 0.0 đến 1.0.
  final double progress;

  const CookingProgressHeader({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bước $stepNumber / $totalSteps',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
