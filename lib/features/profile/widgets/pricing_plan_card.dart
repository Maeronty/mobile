// =============================================================================
// WIDGET: THẺ MỘT GÓI DỊCH VỤ (Pricing)
// =============================================================================
//
// FLOW
//   Bấm nút → hiện SnackBar tên gói đã chọn (chưa tích hợp thanh toán).
//
// LƯU Ý
//   Gói `isRecommended` có viền đậm, nhãn "PHỔ BIẾN NHẤT" và màu chính.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PricingPlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool isRecommended;
  final String buttonText;

  const PricingPlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    this.isRecommended = false,
    required this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecommended
              ? AppColors.primary
              : Theme.of(context).brightness == Brightness.dark
                  ? AppColors.dividerDark
                  : AppColors.dividerLight,
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRecommended)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'PHỔ BIẾN NHẤT',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isRecommended ? AppColors.primary : null,
                ),
              ),
              const SizedBox(width: 4),
              Text('/ $period', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const Divider(height: 24),
          ...features.map((feat) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: isRecommended ? AppColors.primary : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(feat, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              backgroundColor: isRecommended ? AppColors.primary : Colors.grey.shade300,
              foregroundColor: isRecommended ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Bạn đã chọn: $title')),
              );
            },
            child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
