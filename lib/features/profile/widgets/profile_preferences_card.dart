// =============================================================================
// WIDGET: NHÓM TUỲ CHỌN (Hồ sơ)
// =============================================================================
//
// FLOW
//   - Chạm "Chế độ ăn yêu thích" → `onDietTap` → mở dialog chọn chế độ ăn.
//   - Công tắc Thông báo → `onNotificationChanged` → ProfileController.
//   - Công tắc Dark Mode → `onDarkModeToggle` → ThemeController.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'profile_section_card.dart';

class ProfilePreferencesCard extends StatelessWidget {
  final String dietPreference;
  final bool notificationEnabled;
  final bool isDarkMode;
  final VoidCallback onDietTap;
  final ValueChanged<bool> onNotificationChanged;
  final VoidCallback onDarkModeToggle;

  const ProfilePreferencesCard({
    super.key,
    required this.dietPreference,
    required this.notificationEnabled,
    required this.isDarkMode,
    required this.onDietTap,
    required this.onNotificationChanged,
    required this.onDarkModeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      children: [
        ListTile(
          leading: const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary),
          title: const Text('Chế độ ăn yêu thích'),
          subtitle: Text(dietPreference, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onDietTap,
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
          title: const Text('Thông báo gợi ý món ngon'),
          subtitle: const Text('Nhận công thức phù hợp mỗi ngày lúc 10h sáng và 16h chiều', style: TextStyle(fontSize: 12)),
          value: notificationEnabled,
          activeThumbColor: AppColors.primary,
          onChanged: onNotificationChanged,
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
          title: const Text('Giao diện tối (Dark Mode)'),
          value: isDarkMode,
          activeThumbColor: AppColors.primary,
          onChanged: (_) => onDarkModeToggle(),
        ),
      ],
    );
  }
}
