// =============================================================================
// WIDGET: PHẦN ĐẦU MÀN HÌNH GÓI DỊCH VỤ (Pricing)
// =============================================================================
//
// VAI TRÒ
//   Chỉ hiển thị lời giới thiệu gói Pro, không có tương tác.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PricingHeader extends StatelessWidget {
  const PricingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(Icons.workspace_premium_rounded, size: 48, color: Colors.white),
          SizedBox(height: 10),
          Text(
            'Nâng Tầm Bếp Trưởng Tại Gia',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Mở khóa toàn bộ tính năng cao cấp cùng Cố vấn dinh dưỡng AI không giới hạn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
