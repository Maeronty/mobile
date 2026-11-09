// =============================================================================
// THANH ĐIỀU HƯỚNG CHÍNH (Bottom Navigation — 4 tab)
// =============================================================================
//
// FLOW
//   1. `_currentIndex` quyết định tab đang hiển thị:
//        0 Trang Chủ │ 1 Gợi Ý AI │ 2 Túi Thần Kỳ │ 3 Cá Nhân
//   2. Dùng IndexedStack → các tab KHÔNG bị huỷ khi chuyển, giữ nguyên trạng
//      thái (vị trí cuộn, ô tìm kiếm...).
//   3. Chuyển tab bằng: bấm NavigationBar, hoặc HomeScreen gọi
//      `onNavigateTab(index)` từ các thẻ CTA.
//
// LƯU Ý
//   - NutritionAdvisorScreen (features/nutrition) đã có nhưng CHƯA được gắn
//     vào tab nào.
// =============================================================================

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../features/home/home_screen.dart';
import '../features/kitchen_bag/kitchen_bag_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/suggest/suggest_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onNavigateTab: _navigateToTab),
      const SuggestScreen(),
      const KitchenBagScreen(),
      const ProfileScreen(),
    ];
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateToTab,
        backgroundColor: Theme.of(context).cardTheme.color,
        indicatorColor: AppColors.primaryLight,
        elevation: 4,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryDark),
            label: 'Trang Chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark),
            label: 'Gợi Ý AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen_rounded, color: AppColors.primaryDark),
            label: 'Túi Thần Kỳ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryDark),
            label: 'Cá Nhân',
          ),
        ],
      ),
    );
  }
}
