// =============================================================================
// MÀN HÌNH: HỒ SƠ & CÀI ĐẶT (tab "Cá Nhân")
// =============================================================================
//
// FILE NÀY CHỈ GHÉP CÁC KHU VỰC GIAO DIỆN; từng khu vực nằm trong `widgets/`.
//   - Thông tin người dùng, thông báo           → `profile_controller.dart`.
//   - Số món đã lưu                             → FavoritesController.
//   - Dark Mode                                 → ThemeController.
//
// FLOW UI
//   1. initState → lắng nghe ProfileController & FavoritesController để tự
//      build lại khi tuỳ chọn hoặc số món yêu thích thay đổi.
//   2. Công tắc Thông báo / Dark Mode → controller tương ứng.
//
// LƯU Ý
//   `isDark` lấy từ `Theme.of(context)` để màn hình phụ thuộc vào Theme và tự
//   build lại khi đổi giao diện (không có setState khi toggle).
// =============================================================================

import 'package:flutter/material.dart';
import '../favorites/favorites_controller.dart';
import '../theme/theme_controller.dart';
import 'profile_controller.dart';
import 'widgets/profile_header_card.dart';
import 'widgets/profile_help_card.dart';
import 'widgets/profile_logout_button.dart';
import 'widgets/profile_preferences_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileController _profile = ProfileController.instance;
  final FavoritesController _favorites = FavoritesController.instance;

  @override
  void initState() {
    super.initState();
    _profile.addListener(_onChanged);
    _favorites.addListener(_onChanged);
  }

  @override
  void dispose() {
    _profile.removeListener(_onChanged);
    _favorites.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ Sơ & Cài Đặt'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: theme.toggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProfileHeaderCard(
              user: _profile.currentUser,
              savedCount: _favorites.favoriteIds.length,
            ),

            const SizedBox(height: 20),

            ProfilePreferencesCard(
              notificationEnabled: _profile.notificationEnabled,
              isDarkMode: isDark,
              onNotificationChanged: _profile.setNotificationEnabled,
              onDarkModeToggle: theme.toggleTheme,
            ),

            const SizedBox(height: 16),

            const ProfileHelpCard(),

            const SizedBox(height: 20),

            const ProfileLogoutButton(),
          ],
        ),
      ),
    );
  }
}
