// =============================================================================
// WIDGET: KHUNG NHÓM MỤC (Hồ sơ)
// =============================================================================
//
// VAI TRÒ
//   Khung bo góc có viền, dùng chung cho nhóm "Tuỳ chọn" và "Hỗ trợ".
//
// LƯU Ý
//   Dùng Material + clipBehavior để hiệu ứng chạm của ListTile không tràn góc.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ProfileSectionCard extends StatelessWidget {
  final List<Widget> children;

  const ProfileSectionCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
