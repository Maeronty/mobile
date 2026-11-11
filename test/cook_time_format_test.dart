// Định dạng thời gian nấu: không rõ → null (UI ẩn), ước lượng → có "~".

import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/core/models/cook_time_format.dart';
import 'package:tomato_food_tip/core/models/recipe_summary.dart';

void main() {
  test('đầy đủ', () {
    expect(formatCookTime(0), isNull);
    expect(formatCookTime(45), '45 phút');
    expect(formatCookTime(70, estimated: true), '~1 giờ 10 phút');
    expect(formatCookTime(240), '4 giờ');
  });

  test('rút gọn cho thẻ nhỏ', () {
    expect(formatCookTimeShort(0), isNull);
    expect(formatCookTimeShort(25, estimated: true), '~25p');
    expect(formatCookTimeShort(250), '4g10');
    expect(formatCookTimeShort(60), '1g');
  });

  test('thẻ món đọc cờ ước lượng từ server', () {
    final card = RecipeSummary.fromJson({
      'id': 1, 'title': 'Ba rọi chiên sả ớt', 'category': 'Món chiên',
      'cookTimeMinutes': 250, 'cookTimeEstimated': true, 'calories': 0, 'ingredientCount': 9,
    });
    expect(card.metaLabel, 'Món chiên · 9 nguyên liệu · ~4 giờ 10 phút');

    final unknown = RecipeSummary.fromJson({'id': 2, 'title': 'Gỏi', 'cookTimeMinutes': 0, 'ingredientCount': 5});
    expect(unknown.metaLabel, '5 nguyên liệu');
  });
}
