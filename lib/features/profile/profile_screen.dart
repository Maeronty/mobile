// =============================================================================
// MÀN HÌNH: HỒ SƠ & CÀI ĐẶT (tab "Cá Nhân")
// =============================================================================
//
// FILE NÀY CHỈ CHỨA GIAO DIỆN.
//   - Thông tin người dùng, chế độ ăn, thông báo → `profile_controller.dart`.
//   - Số món đã lưu                             → FavoritesController.
//   - Dark Mode                                 → ThemeController.
//
// FLOW UI
//   1. initState → lắng nghe ProfileController & FavoritesController để tự
//      build lại khi tuỳ chọn hoặc số món yêu thích thay đổi.
//   2. Bấm thẻ nâng cấp → mở PricingScreen.
//   3. "Chế độ ăn uống" → `_showDietPreferenceDialog` → setDietPreference.
//   4. Công tắc Thông báo / Dark Mode → controller tương ứng.
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../favorites/favorites_controller.dart';
import '../theme/theme_controller.dart';
import 'pricing_screen.dart';
import 'profile_controller.dart';

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
    final user = _profile.currentUser;
    final isDark = theme.isDarkMode;

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
            // User Header Card
            Container(
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
                      _buildStatColumn('Đã lưu', '${_favorites.favoriteIds.length} món'),
                      Container(width: 1, height: 28, color: Colors.grey.withOpacity(0.2)),
                      _buildStatColumn('Đã nấu', '${user.cookedCount} lần'),
                      Container(width: 1, height: 28, color: Colors.grey.withOpacity(0.2)),
                      _buildStatColumn('Theo dõi', '${user.followersCount} người'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pro Membership Banner
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PricingScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gói Thành Viên: Bếp Việt Pro VIP',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Khám phá các đặc quyền cao cấp cho bếp trưởng',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Preferences Section
            Material(
              color: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary),
                    title: const Text('Chế độ ăn yêu thích'),
                    subtitle: Text(_profile.dietPreference, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      _showDietPreferenceDialog();
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                    title: const Text('Thông báo gợi ý món ngon'),
                    subtitle: const Text('Nhận công thức phù hợp mỗi ngày lúc 10h sáng và 16h chiều', style: TextStyle(fontSize: 12)),
                    value: _profile.notificationEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: _profile.setNotificationEnabled,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                    title: const Text('Giao diện tối (Dark Mode)'),
                    value: isDark,
                    activeThumbColor: AppColors.primary,
                    onChanged: (_) => theme.toggleTheme(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Help & Info Section
            Material(
              color: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                    title: const Text('Trung tâm hỗ trợ & Góp ý'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hỗ trợ: support@tomato-foodtip.vn')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.policy_outlined, color: AppColors.primary),
                    title: const Text('Điều khoản sử dụng & Chính sách'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bản quyền thuộc về Bếp Việt Food Tip System.')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Logout Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất tài khoản'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang ở chế độ trải nghiệm khách.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  void _showDietPreferenceDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Chọn chế độ ăn uống'),
        children: ProfileController.dietOptions.map((opt) {
          return SimpleDialogOption(
            onPressed: () {
              _profile.setDietPreference(opt);
              Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(opt, style: const TextStyle(fontSize: 15)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
