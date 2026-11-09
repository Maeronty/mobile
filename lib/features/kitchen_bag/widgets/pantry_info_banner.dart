// =============================================================================
// WIDGET: BANNER GIỚI THIỆU KHO NGUYÊN LIỆU (tab "Tủ Lạnh Của Bạn")
// =============================================================================
//
// VAI TRÒ
//   Chỉ hiển thị lời giới thiệu, không có tương tác.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PantryInfoBanner extends StatelessWidget {
  const PantryInfoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.primary.withOpacity(0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Kho nguyên liệu gia đình',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Lưu trữ những gì bạn đang có trong tủ lạnh. Bếp Việt sẽ tự động tìm các món bạn có thể nấu ngay!',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
