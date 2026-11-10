import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/app/app.dart';

import 'package:tomato_food_tip/core/data/recipe_repository.dart';
import 'package:tomato_food_tip/core/widgets/recipe_card.dart';
import 'package:tomato_food_tip/features/home/widgets/home_trending_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => RecipeRepository.instance.load(online: false));
  testWidgets('TomatoFoodTipApp smoke test and Nutrition navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TomatoFoodTipApp());
    expect(find.text('Bếp Việt'), findsOneWidget);
    expect(find.text('Dinh Dưỡng'), findsOneWidget);
    expect(find.text('Cố Vấn Dinh Dưỡng AI'), findsOneWidget);

    await tester.tap(find.text('Dinh Dưỡng'));
    await tester.pumpAndSettle();
    expect(find.text('Dinh Dưỡng & Thực Đơn AI'), findsOneWidget);
    expect(find.text('Tạo lại thực đơn thông minh'), findsOneWidget);
  });

  testWidgets('HomeTrendingSection keeps RecipeCard height compact on wide screens',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeTrendingSection(
              title: 'Món ăn thịnh hành',
              recipes: RecipeRepository.instance.all.take(4).toList(),
              onFavoriteToggled: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardRect = tester.getRect(find.byType(RecipeCard).first);
    expect(cardRect.height, lessThan(280));
  });
}
