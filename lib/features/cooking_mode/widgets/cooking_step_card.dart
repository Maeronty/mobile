// =============================================================================
// WIDGET: THẺ NỘI DUNG BƯỚC NẤU (Cooking Mode)
// =============================================================================
//
// VAI TRÒ
//   Ghép nhãn bước, nội dung hướng dẫn và mẹo đầu bếp (nếu có).
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/models/recipe.dart';
import '../../../core/theme/app_colors.dart';
import 'cooking_chef_tip.dart';

class CookingStepCard extends StatelessWidget {
  final int stepNumber;
  final InstructionStep step;

  const CookingStepCard({
    super.key,
    required this.stepNumber,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'HƯỚNG DẪN BƯỚC $stepNumber',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Step Content
          Text(
            step.description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Chef Tip
          if (step.tip != null) ...[
            const SizedBox(height: 24),
            CookingChefTip(tip: step.tip!),
          ],
        ],
      ),
    );
  }
}
