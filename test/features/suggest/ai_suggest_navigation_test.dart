import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/core/data/recipe_repository.dart';
import 'package:tomato_food_tip/features/cooking_mode/cooking_mode_screen.dart';
import 'package:tomato_food_tip/features/favorites/favorites_controller.dart';
import 'package:tomato_food_tip/features/recipe_detail/recipe_detail_screen.dart';
import 'package:tomato_food_tip/features/suggest/ai_suggest_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RecipeRepository.instance.load(online: false);
  });

  group('RecipeRepository R1 Enhancements', () {
    test('findByIdOrNull returns existing recipe or null if not found', () {
      final repo = RecipeRepository.instance;
      final existingId = repo.all.first.id;
      expect(repo.findByIdOrNull(existingId), isNotNull);
      expect(repo.findByIdOrNull(existingId)!.id, equals(existingId));

      expect(repo.findByIdOrNull(888888), isNull);
    });

    test('addRecipe adds a new recipe without throwing unmodifiable error', () {
      final repo = RecipeRepository.instance;
      const testId = 777777;
      final newRecipe = repo.createCompatibleRecipe(
        id: testId,
        title: 'Món thử nghiệm addRecipe',
        used: ['Thịt bò'],
        missing: ['Hành tây'],
      );
      repo.addRecipe(newRecipe);

      expect(repo.findByIdOrNull(testId), isNotNull);
      expect(repo.findById(testId).title, equals('Món thử nghiệm addRecipe'));
    });

    test('findById creates and registers fallback recipe for uncataloged ID', () {
      final repo = RecipeRepository.instance;
      const unknownId = 999123;
      expect(repo.findByIdOrNull(unknownId), isNull);

      final recipe = repo.findById(unknownId);
      expect(recipe, isNotNull);
      expect(recipe.id, equals(unknownId));
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.instructions, isNotEmpty);
      expect(recipe.instructions.first.estimatedMinutes, isNotNull);

      // Verify it was added to repo
      expect(repo.findByIdOrNull(unknownId), isNotNull);
    });
  });

  group('AiSuggestScreen Navigation to RecipeDetailScreen & CookingModeScreen', () {
    testWidgets('Tapping catalog recipe suggestion opens RecipeDetailScreen and CookingModeScreen', (tester) async {
      final repo = RecipeRepository.instance;
      final catalogRecipe = repo.all.first;

      final suggestions = [
        {
          'id': catalogRecipe.id,
          'title': catalogRecipe.title,
          'reason': 'Món ăn quen thuộc giàu dinh dưỡng',
          'used': ['Trứng', 'Cà chua'],
          'missing': <String>[],
        }
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestScreen(
            ingredients: const ['Trứng', 'Cà chua'],
            initialRecipes: suggestions,
          ),
        ),
      );

      expect(find.text(catalogRecipe.title), findsOneWidget);
      expect(find.text('Xem chi tiết & Nấu ăn'), findsOneWidget);

      // Tap on the button
      await tester.tap(find.text('Xem chi tiết & Nấu ăn'));
      await tester.pumpAndSettle();

      // Verify navigated to RecipeDetailScreen
      expect(find.byType(RecipeDetailScreen), findsOneWidget);
      expect(find.text(catalogRecipe.title), findsWidgets);
      expect(find.text('Bắt đầu chế độ nấu ăn (Cooking Mode)'), findsOneWidget);

      // Tap start cooking bar
      await tester.tap(find.text('Bắt đầu chế độ nấu ăn (Cooking Mode)'));
      await tester.pumpAndSettle();

      // Verify navigated to CookingModeScreen
      expect(find.byType(CookingModeScreen), findsOneWidget);
      expect(find.text('Bước 1 / ${catalogRecipe.instructions.length}'), findsOneWidget);
    });

    testWidgets('Tapping uncataloged recipe suggestion safely synthesizes Recipe and navigates to CookingModeScreen', (tester) async {
      const uncatalogedId = 987654;
      final suggestions = [
        {
          'id': uncatalogedId,
          'title': 'Canh chua cá lóc Nam Bộ',
          'reason': 'Món canh giải nhiệt từ cá lóc và dứa',
          'used': ['Cá lóc', 'Cà chua'],
          'missing': ['Bạc hà', 'Đậu bắp'],
        }
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestScreen(
            ingredients: const ['Cá lóc', 'Cà chua'],
            initialRecipes: suggestions,
          ),
        ),
      );

      expect(find.text('Canh chua cá lóc Nam Bộ'), findsOneWidget);
      expect(find.text('Đã có: Cá lóc, Cà chua'), findsOneWidget);
      expect(find.text('Cần thêm: Bạc hà, Đậu bắp'), findsOneWidget);

      // Tap card
      await tester.tap(find.text('Canh chua cá lóc Nam Bộ'));
      await tester.pumpAndSettle();

      // Verify RecipeDetailScreen opens without StateError or exception
      expect(find.byType(RecipeDetailScreen), findsOneWidget);
      expect(find.text('Canh chua cá lóc Nam Bộ'), findsWidgets);

      // Verify synthesized ingredients are displayed
      expect(find.text('Cá lóc'), findsOneWidget);
      expect(find.text('Bạc hà'), findsOneWidget);

      // Verify favorite functionality works with synthesized recipe
      final favorites = FavoritesController.instance;
      expect(favorites.isFavorite(uncatalogedId), isFalse);
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();
      expect(favorites.isFavorite(uncatalogedId), isTrue);
      expect(favorites.favoriteRecipes.any((r) => r.id == uncatalogedId), isTrue);

      // Navigate to CookingModeScreen
      expect(find.text('Bắt đầu chế độ nấu ăn (Cooking Mode)'), findsOneWidget);
      await tester.tap(find.text('Bắt đầu chế độ nấu ăn (Cooking Mode)'));
      await tester.pumpAndSettle();

      // Verify CookingModeScreen works with synthesized instructions
      expect(find.byType(CookingModeScreen), findsOneWidget);
      expect(find.text('Bước 1 / 3'), findsOneWidget);
      expect(find.textContaining('Sơ chế và rửa sạch'), findsOneWidget);

      // Test timer toggle in CookingModeScreen
      final playButton = find.byIcon(Icons.play_arrow_rounded);
      await tester.ensureVisible(playButton);
      await tester.pumpAndSettle();
      expect(playButton, findsOneWidget);
      await tester.tap(playButton);
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });
  });
}
