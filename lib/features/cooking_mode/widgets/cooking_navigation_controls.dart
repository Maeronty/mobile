// =============================================================================
// WIDGET: NÚT CHUYỂN BƯỚC (Cooking Mode)
// =============================================================================
//
// FLOW
//   - "Bước trước" chỉ hiện từ bước thứ 2 trở đi → `onPrevious`.
//   - Nút chính → `onNext`; ở bước cuối đổi nhãn thành "Hoàn thành món ăn".
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CookingNavigationControls extends StatelessWidget {
  final bool showPrevious;
  final bool isLastStep;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const CookingNavigationControls({
    super.key,
    required this.showPrevious,
    required this.isLastStep,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (showPrevious)
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Bước trước'),
                onPressed: onPrevious,
              ),
            ),
          if (showPrevious) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(
                isLastStep ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
              ),
              label: Text(
                isLastStep ? 'Hoàn thành món ăn' : 'Bước tiếp theo',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: onNext,
            ),
          ),
        ],
      ),
    );
  }
}
