// =============================================================================
// WIDGET: THANH "NẤU NGAY" DÍNH ĐÁY (Surprise Me)
// =============================================================================
//
// FLOW
//   - Hiển thị số món khớp bộ lọc.
//   - Có món → bấm nút → `onStart` → đầu bếp bắt đầu nấu.
//   - Không có món (`matchCount = 0`) → nút bị khoá, nhắc nới lỏng bộ lọc.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SurpriseStartBar extends StatelessWidget {
  final int matchCount;
  final VoidCallback onStart;

  const SurpriseStartBar({
    super.key,
    required this.matchCount,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge đếm số món thỏa mãn
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                matchCount > 0
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 16,
                color: matchCount > 0 ? AppColors.success : AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                matchCount > 0
                    ? '$matchCount món ăn sẵn sàng phục vụ'
                    : 'Không có món phù hợp, hãy nới lỏng bộ lọc nhé!',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: matchCount > 0
                      ? (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight)
                      : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: matchCount > 0 ? onStart : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.grey.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Đầu bếp bí mật, nấu ngay!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
