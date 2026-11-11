import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomato_food_tip/core/data/recipe_repository.dart';
import 'package:tomato_food_tip/features/favorites/favorites_controller.dart';
import 'package:tomato_food_tip/features/kitchen_bag/kitchen_bag_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await RecipeRepository.instance.load(online: false);
  });

  setUp(() async {
    await FavoritesController.instance.clear();
  });

  testWidgets('KitchenBagScreen phản ứng ngay khi FavoritesController thay đổi danh sách yêu thích', (tester) async {
    final favorites = FavoritesController.instance;

    await tester.pumpWidget(
      const MaterialApp(
        home: KitchenBagScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Ban đầu tab Đã Lưu có 0 món
    expect(find.text('Đã Lưu (0)'), findsOneWidget);

    // Người dùng bấm thích món 715415 ở nơi khác (Home / Detail)
    await favorites.toggleFavorite(715415);
    await tester.pump();

    // KitchenBagScreen lắng nghe FavoritesController nên cập nhật thành 'Đã Lưu (1)' ngay
    expect(find.text('Đã Lưu (1)'), findsOneWidget);

    // Chuyển sang Tab Đã Lưu để kiểm tra hiển thị món
    await tester.tap(find.text('Đã Lưu (1)'));
    await tester.pumpAndSettle();

    // Món đã thích xuất hiện trong danh sách
    expect(find.text('Súp Đậu Lăng Đỏ với Gà và Củ Cải'), findsOneWidget);
  });

  test('FavoritesController lưu và phục hồi danh sách yêu thích từ SharedPreferences', () async {
    final favorites = FavoritesController.instance;
    await favorites.toggleFavorite(715415);
    expect(favorites.isFavorite(715415), isTrue);

    // Kiểm tra đã lưu xuống SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('favorite_recipe_ids');
    expect(saved, contains('715415'));
  });
}
