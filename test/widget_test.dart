import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/app/app.dart';

import 'package:tomato_food_tip/core/data/recipe_repository.dart';

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
}
