import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/app/app.dart';

void main() {
  testWidgets('TomatoFoodTipApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TomatoFoodTipApp());
    expect(find.text('Bếp Việt'), findsOneWidget);
  });
}
