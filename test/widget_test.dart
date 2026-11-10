import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/app/app.dart';

import 'package:tomato_food_tip/core/data/recipe_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => RecipeRepository.instance.load(online: false));
  testWidgets('TomatoFoodTipApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TomatoFoodTipApp());
    expect(find.text('Bếp Việt'), findsOneWidget);
  });
}
