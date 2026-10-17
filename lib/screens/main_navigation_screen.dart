import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'home/home_screen.dart';
import 'suggest/suggest_screen.dart';
import 'kitchen_bag/kitchen_bag_screen.dart';
import 'community/community_screen.dart';
import 'nutrition/nutrition_advisor_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigateTab: _navigateToTab),
      const SuggestScreen(),
      const KitchenBagScreen(),
      const CommunityScreen(),
      const NutritionAdvisorScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded, color: AppColors.primaryDark),
            label: 'Cộng Đồng',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu_rounded, color: AppColors.primaryDark),
            label: 'Dinh Dưỡng',
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
