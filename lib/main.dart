import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'services/app_state.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TomatoFoodTipApp());
}

class TomatoFoodTipApp extends StatelessWidget {
  const TomatoFoodTipApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppState();

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Bếp Việt - Food Tip System',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}
