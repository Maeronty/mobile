import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomato_food_tip/app/app.dart';
import 'package:tomato_food_tip/app/main_navigation_screen.dart';
import 'package:tomato_food_tip/core/data/recipe_repository.dart';
import 'package:tomato_food_tip/features/auth/auth_controller.dart';
import 'package:tomato_food_tip/features/auth/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await RecipeRepository.instance.load(online: false);
    await AuthController.instance.restoreSession();
  });

  testWidgets('chưa đăng nhập → màn đăng nhập; dùng thử → vào app; đăng xuất → quay lại', (tester) async {
    await tester.pumpWidget(const TomatoFoodTipApp());
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.ensureVisible(find.text('Dùng thử không cần tài khoản'));
    await tester.tap(find.text('Dùng thử không cần tài khoản'));
    await tester.pump();
    expect(find.byType(MainNavigationScreen), findsOneWidget);

    await AuthController.instance.logout();
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('đăng ký báo lỗi ngay khi mật khẩu yếu, không gọi server', (tester) async {
    await tester.pumpWidget(const TomatoFoodTipApp());
    await tester.ensureVisible(find.text('Đăng ký ngay'));
    await tester.tap(find.text('Đăng ký ngay'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Tên hiển thị'), 'An');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'an@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mật khẩu'), 'matkhau123');
    await tester.ensureVisible(find.text('Tạo tài khoản'));
    await tester.tap(find.text('Tạo tài khoản'));
    await tester.pump();

    expect(find.text('Cần ít nhất 1 chữ hoa'), findsOneWidget);
    expect(AuthController.instance.isLoggedIn, isFalse);
  });
}
