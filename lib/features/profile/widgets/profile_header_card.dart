// =============================================================================
// WIDGET: THẺ THÔNG TIN NGƯỜI DÙNG (Hồ sơ)
// =============================================================================
//
// VAI TRÒ
//   Hiển thị ảnh đại diện, tên, vai trò, giới thiệu và 3 chỉ số thống kê.
//
// LƯU Ý
//   `savedCount` lấy từ FavoritesController, không dùng `savedRecipesCount` của
//   user, để con số luôn khớp với số món đã thả tim.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/theme/app_colors.dart';
import 'profile_stat_column.dart';

class ProfileHeaderCard extends StatelessWidget {
  final UserProfile user;
  final int savedCount;

  const ProfileHeaderCard({
    super.key,
    required this.user,
    required this.savedCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primaryLight,
            child: const Icon(Icons.person_rounded, size: 40, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      user.role,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            user.bio,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ProfileStatColumn(label: 'Đã lưu', value: '$savedCount món'),
              Container(width: 1, height: 28, color: Colors.grey.withOpacity(0.2)),
              ProfileStatColumn(label: 'Đã nấu', value: '${user.cookedCount} lần'),
              Container(width: 1, height: 28, color: Colors.grey.withOpacity(0.2)),
              ProfileStatColumn(label: 'Theo dõi', value: '${user.followersCount} người'),
            ],
          ),
        ],
      ),
    );
  }
}
