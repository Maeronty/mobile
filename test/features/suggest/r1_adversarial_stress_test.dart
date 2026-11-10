import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/core/data/recipe_repository.dart';
import 'package:tomato_food_tip/core/models/recipe.dart';
import 'package:tomato_food_tip/features/cooking_mode/cooking_mode_controller.dart';
import 'package:tomato_food_tip/features/cooking_mode/cooking_mode_screen.dart';
import 'package:tomato_food_tip/features/recipe_detail/recipe_detail_controller.dart';
import 'package:tomato_food_tip/features/recipe_detail/recipe_detail_screen.dart';
import 'package:tomato_food_tip/features/suggest/ai_suggest_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RecipeRepository.instance.load(online: false);
  });

  group('Adversarial Stress Test: RecipeRepository Resilience', () {
    test('Handles negative, zero, and extreme recipe IDs safely', () {
      final repo = RecipeRepository.instance;

      for (final badId in [-1, -999999, 0, 2147483647]) {
        final recipe = repo.findById(badId);
        expect(recipe, isNotNull);
        expect(recipe.id, equals(badId));
        expect(recipe.ingredients, isNotEmpty);
        expect(recipe.instructions, isNotEmpty);
        expect(recipe.instructions.first.estimatedMinutes, isNotNull);
        expect(repo.findByIdOrNull(badId), isNotNull);

        // Subsequent findById call returns the same registered recipe
        final cached = repo.findById(badId);
        expect(identical(recipe, cached), isTrue);
      }
    });

    test('addRecipe is idempotent and safe against repeated additions', () {
      final repo = RecipeRepository.instance;
      const testId = 888123;
      final recipe = repo.createCompatibleRecipe(
        id: testId,
        title: 'Thử nghiệm idempotent',
      );

      final countBefore = repo.all.length;
      repo.addRecipe(recipe);
      expect(repo.all.length, equals(countBefore + 1));

      // Adding the same recipe again must not duplicate or throw
      repo.addRecipe(recipe);
      expect(repo.all.length, equals(countBefore + 1));
      expect(repo.all.where((r) => r.id == testId).length, equals(1));
    });

    test('createCompatibleRecipe handles all-empty and all-whitespace ingredients', () {
      final repo = RecipeRepository.instance;

      final emptyRecipe = repo.createCompatibleRecipe(
        id: 70001,
        title: '',
        used: const [],
        missing: const [],
      );
      expect(emptyRecipe.ingredients, isNotEmpty,
          reason: 'Must synthesize a fallback ingredient when empty');
      expect(emptyRecipe.ingredients.first.name, equals('Nguyên liệu chính'));
      expect(emptyRecipe.matchScore, equals(1.0));

      final whitespaceRecipe = repo.createCompatibleRecipe(
        id: 70002,
        title: '   ',
        used: ['   ', '\t', '\n'],
        missing: ['', '   '],
      );
      expect(whitespaceRecipe.ingredients, isNotEmpty);
      expect(whitespaceRecipe.ingredients.first.name, equals('Nguyên liệu chính'));
    });

    test('createCompatibleRecipe handles extreme strings, unicode, emojis, and injection tokens', () {
      final repo = RecipeRepository.instance;
      final hugeTitle = '🍲 ' * 500;
      final xssReason = '<script>alert("xss")</script>\'"; DROP TABLE recipes;--\u0000\uFFFF';

      final recipe = repo.createCompatibleRecipe(
        id: 70003,
        title: hugeTitle,
        description: xssReason,
        used: ['Thịt bò \u{1F969}', 'Rau củ <bold>tươi</bold>'],
        missing: ['Hành tây \u{1F9C5}', 'Gia vị đặc biệt & special !@#\$%^&*()'],
      );

      expect(recipe.title, equals(hugeTitle));
      expect(recipe.description, equals(xssReason));
      expect(recipe.ingredients.length, equals(4));
      expect(recipe.matchedIngredients.length, equals(2));
      expect(recipe.missingIngredients.length, equals(2));
      expect(recipe.instructions.length, equals(3));
    });
  });

  group('Adversarial Stress Test: RecipeDetailController & Serving Scaler', () {
    test('Guards against divide-by-zero when recipe servings is 0', () {
      const zeroServingRecipe = Recipe(
        id: 71001,
        title: 'Món 0 khẩu phần',
        description: 'Test serving zero',
        imageAsset: '',
        category: 'Món chính',
        tags: ['Test'],
        cookTimeMinutes: 10,
        difficulty: 'Dễ',
        servings: 0,
        calories: 100,
        averageRating: 5.0,
        totalRatings: 1,
        ingredients: [
          IngredientItem(name: 'Muối', amount: 5.0, unit: 'g'),
        ],
        instructions: [
          InstructionStep(stepNumber: 1, description: 'Rắc muối'),
        ],
        nutrition: NutritionInfo(
          calories: 100,
          proteinGrams: 5,
          carbsGrams: 10,
          fatGrams: 2,
        ),
      );

      final controller = RecipeDetailController(
        recipeId: 71001,
        initialRecipe: zeroServingRecipe,
      );

      expect(controller.servings, equals(0));
      // scaleFactor should fallback to recipe.servings == 0 ? 1 : recipe.servings
      expect(controller.scaleFactor.isFinite, isTrue);
      expect(controller.formatScaledAmount(5.0), isNotNull);

      // Decreasing at 0 must not crash or go negative
      controller.decreaseServings();
      expect(controller.servings, equals(0));

      // Increasing should work
      controller.increaseServings();
      expect(controller.servings, equals(1));
      expect(controller.scaleFactor, equals(1.0));
      expect(controller.formatScaledAmount(5.0), equals('5'));

      controller.dispose();
    });

    test('Serving scaling lower bound and amount formatting', () {
      final repo = RecipeRepository.instance;
      final recipe = repo.createCompatibleRecipe(id: 71002, title: 'Test scaling');
      final controller = RecipeDetailController(recipeId: 71002, initialRecipe: recipe);

      expect(controller.servings, equals(2));
      controller.decreaseServings();
      expect(controller.servings, equals(1));
      // Attempting to decrease below 1 must stay at 1
      controller.decreaseServings();
      expect(controller.servings, equals(1));

      // Scale to 10 servings
      for (int i = 0; i < 9; i++) {
        controller.increaseServings();
      }
      expect(controller.servings, equals(10));
      expect(controller.scaleFactor, equals(5.0));

      expect(controller.formatScaledGrams(0.0), equals('0'));
      expect(controller.formatScaledGrams(12.34), equals('62'));
      expect(controller.formatScaledAmount(0.0), equals('0'));
      expect(controller.formatScaledAmount(1.5), equals('7.5'));
      expect(controller.formatScaledAmount(2.0), equals('10'));

      // Toggle ingredient check repeatedly
      expect(controller.checkedCount, equals(0));
      controller.toggleIngredientCheck(0);
      expect(controller.checkedCount, equals(1));
      expect(controller.isIngredientChecked(0), isTrue);
      controller.toggleIngredientCheck(0);
      expect(controller.checkedCount, equals(0));
      expect(controller.isIngredientChecked(0), isFalse);

      controller.dispose();
    });
  });

  group('Adversarial Stress Test: CookingModeController Edge Cases', () {
    test('Handles single-step recipe with null estimatedMinutes and rapid timer cycling', () {
      const singleStepRecipe = Recipe(
        id: 72002,
        title: 'Món 1 bước duy nhất',
        description: 'Single step',
        imageAsset: '',
        category: 'Món nhanh',
        tags: [],
        cookTimeMinutes: 1,
        difficulty: 'Dễ',
        servings: 1,
        calories: 50,
        averageRating: 5.0,
        totalRatings: 1,
        ingredients: [],
        instructions: [
          InstructionStep(stepNumber: 1, description: 'Chỉ có 1 bước', estimatedMinutes: null),
        ],
        nutrition: NutritionInfo(calories: 50, proteinGrams: 2, carbsGrams: 5, fatGrams: 1),
      );

      bool timerFinishedCalled = false;
      final controller = CookingModeController(
        recipe: singleStepRecipe,
        onTimerFinished: () => timerFinishedCalled = true,
      );

      expect(controller.totalSteps, equals(1));
      expect(controller.isFirstStep, isTrue);
      expect(controller.isLastStep, isTrue);
      expect(controller.progress, equals(1.0));
      expect(controller.secondsLeft, equals(CookingModeController.defaultStepMinutes * 60));

      // Rapidly toggle timer 10 times
      for (int i = 0; i < 10; i++) {
        controller.toggleTimer();
      }
      expect(controller.isTimerRunning, isFalse);

      // Reset timer
      controller.resetTimer();
      expect(controller.secondsLeft, equals(CookingModeController.defaultStepMinutes * 60));

      // toggle voice
      expect(controller.isVoiceSpeaking, isFalse);
      expect(controller.toggleVoice(), isTrue);
      expect(controller.isVoiceSpeaking, isTrue);
      expect(controller.toggleVoice(), isFalse);

      // nextStep at last step returns false
      expect(controller.nextStep(), isFalse);

      // prevStep at first step does nothing
      controller.prevStep();
      expect(controller.currentStepIndex, equals(0));

      controller.dispose();
      expect(timerFinishedCalled, isFalse);
    });

    test('100-step recipe boundary transitions and formatTime', () {
      final manySteps = List.generate(
        100,
        (i) => InstructionStep(
          stepNumber: i + 1,
          description: 'Bước $i',
          estimatedMinutes: i % 10 + 1,
        ),
      );

      final bigRecipe = Recipe(
        id: 72003,
        title: 'Món 100 bước',
        description: '100 steps recipe',
        imageAsset: '',
        category: 'Phức tạp',
        tags: [],
        cookTimeMinutes: 500,
        difficulty: 'Khó',
        servings: 4,
        calories: 800,
        averageRating: 4.5,
        totalRatings: 10,
        ingredients: [],
        instructions: manySteps,
        nutrition: NutritionInfo(calories: 800, proteinGrams: 40, carbsGrams: 80, fatGrams: 25),
      );

      final controller = CookingModeController(recipe: bigRecipe);
      expect(controller.totalSteps, equals(100));

      // Step forward 99 times
      for (int i = 0; i < 99; i++) {
        expect(controller.nextStep(), isTrue);
      }
      expect(controller.isLastStep, isTrue);
      expect(controller.nextStep(), isFalse);

      // Step backward 99 times
      for (int i = 0; i < 99; i++) {
        controller.prevStep();
      }
      expect(controller.isFirstStep, isTrue);

      // formatTime helper
      expect(CookingModeController.formatTime(0), equals('00:00'));
      expect(CookingModeController.formatTime(59), equals('00:59'));
      expect(CookingModeController.formatTime(60), equals('01:00'));
      expect(CookingModeController.formatTime(3599), equals('59:59'));
      expect(CookingModeController.formatTime(3600), equals('60:00'));

      controller.dispose();
    });
  });

  group('Adversarial Stress Test: AiSuggestScreen Widget Resilience', () {
    testWidgets('Renders and navigates safely with negative recipe ID and empty ingredients', (tester) async {
      final suggestions = [
        {
          'id': -42, // Negative ID
          'title': 'Món ID Âm -42',
          'reason': 'Lý do hợp lệ',
          'used': ['Thịt gà'],
          'missing': ['Lá chanh'],
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestScreen(
            ingredients: const ['Thịt gà'],
            initialRecipes: suggestions,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Món ID Âm -42'), findsOneWidget);
      final cardFinder = find.text('Món ID Âm -42');
      await tester.ensureVisible(cardFinder);
      await tester.pump();

      // Tap card with negative ID
      await tester.tap(cardFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify RecipeDetailScreen opens safely
      expect(find.byType(RecipeDetailScreen), findsOneWidget);
      expect(find.text('Món ID Âm -42'), findsWidgets);

      // Tap Cooking Mode
      final cookFinder = find.text('Bắt đầu chế độ nấu ăn (Cooking Mode)');
      await tester.ensureVisible(cookFinder);
      await tester.pump();
      await tester.tap(cookFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(CookingModeScreen), findsOneWidget);
      expect(find.text('Món ID Âm -42'), findsOneWidget);
    });

    testWidgets('Renders and navigates with non-integer string ID and null reason/lists', (tester) async {
      final suggestions = [
        {
          'id': '999888', // String format ID
          'title': 'Món String ID 999888',
          'reason': null, // Null reason
          'used': null, // Null used list
          'missing': null, // Null missing list
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestScreen(
            ingredients: const ['Nấm'],
            initialRecipes: suggestions,
          ),
        ),
      );
      await tester.pump();

      final buttonFinder = find.text('Xem chi tiết & Nấu ăn');
      expect(buttonFinder, findsOneWidget);
      await tester.ensureVisible(buttonFinder);
      await tester.pump();

      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify RecipeDetailScreen opens
      expect(find.byType(RecipeDetailScreen), findsOneWidget);
      expect(find.text('Món String ID 999888'), findsWidgets);
    });

    testWidgets('Rapid double tap navigation is handled safely without widget exceptions', (tester) async {
      const rapidTapId = 999111;
      final suggestions = [
        {
          'id': rapidTapId,
          'title': 'Món test đa chạm',
          'reason': 'Stress test rapid taps',
          'used': ['Tôm sú'],
          'missing': ['Tỏi'],
        }
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestScreen(
            ingredients: const ['Tôm sú'],
            initialRecipes: suggestions,
          ),
        ),
      );
      await tester.pump();

      final buttonFinder = find.text('Xem chi tiết & Nấu ăn');
      expect(buttonFinder, findsOneWidget);
      await tester.ensureVisible(buttonFinder);
      await tester.pump();

      // Rapid double tap (~50ms)
      await tester.tap(buttonFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify RecipeDetailScreen opened
      expect(find.byType(RecipeDetailScreen), findsWidgets);

      final cookBarFinder = find.text('Bắt đầu chế độ nấu ăn (Cooking Mode)').first;
      await tester.ensureVisible(cookBarFinder);
      await tester.pump();

      // Rapid double tap on cook button
      await tester.tap(cookBarFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(cookBarFinder, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify CookingModeScreen opened
      expect(find.byType(CookingModeScreen), findsWidgets);
    });

    testWidgets('CookingModeScreen with 0-step recipe renders fallback gracefully', (tester) async {
      const zeroStepsRecipe = Recipe(
        id: 79999,
        title: 'Món rỗng bước UI test',
        description: 'Desc',
        imageAsset: '',
        category: 'Test',
        tags: [],
        cookTimeMinutes: 0,
        difficulty: 'Dễ',
        servings: 1,
        calories: 0,
        averageRating: 0,
        totalRatings: 0,
        ingredients: [],
        instructions: [],
        nutrition: NutritionInfo(calories: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CookingModeScreen(recipe: zeroStepsRecipe),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Món rỗng bước UI test'), findsOneWidget);
      expect(find.text('Công thức này chưa có các bước thực hiện.'), findsOneWidget);
    });
  });
}
