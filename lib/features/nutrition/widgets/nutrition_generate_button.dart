// =============================================================================
// WIDGET: NÚT "TẠO LẠI THỰC ĐƠN THÔNG MINH"
// =============================================================================
//
// FLOW
//   Bấm → `onPressed`. Trong lúc tạo (`isLoading`): nút bị khoá, hiện vòng xoay
//   và đổi nhãn thành "Đang tạo thực đơn...".
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class NutritionGenerateButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const NutritionGenerateButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          backgroundColor: AppColors.primary,
        ),
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(
          isLoading ? 'Đang tạo thực đơn...' : 'Tạo lại thực đơn thông minh',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: isLoading ? null : onPressed,
      ),
    );
  }
}
