// Calo: món có dinh dưỡng thật hiện "N kcal"; món chỉ có calo ước tính cả món
// (từ nguyên liệu) hiện "~N kcal"; không rõ → null (UI ẩn).

import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/core/data/recipe_repository.dart';
import 'package:tomato_food_tip/core/models/calories_format.dart';
import 'package:tomato_food_tip/core/models/recipe.dart';
import 'package:tomato_food_tip/core/models/recipe_summary.dart';

Map<String, dynamic> detail({int calories = 0, bool estimated = false, Map<String, dynamic>? nutrition}) => {
      'id': 1000015, 'title': 'Takoyaki', 'imageUrl': '', 'cookTimeMinutes': 0, 'difficulty': 'Dễ',
      'servings': 0, 'calories': calories, 'caloriesEstimated': estimated, 'averageRating': 0.0,
      'totalRatings': 0, 'source': 'Món Ngon Mỗi Ngày', 'ingredients': [], 'instructions': [],
      'nutrition': nutrition, 'tags': ['Bánh'], 'isFavorited': false,
    };

void main() {
  test('định dạng', () {
    expect(formatCalories(0), isNull);
    expect(formatCalories(170), '170 kcal');
    expect(formatCalories(1220, estimated: true), '~1220 kcal');
  });

  test('chi tiết: calo ước tính cả món khi không có dinh dưỡng', () {
    final r = Recipe.fromDetailJson(detail(calories: 1220, estimated: true));
    expect(r.caloriesLabel, '~1220 kcal');
    expect(r.hasCalories, isTrue);
    expect(r.hasNutrition, isFalse, reason: 'không có đạm/béo/tinh bột thật');

    final unknown = Recipe.fromDetailJson(detail());
    expect(unknown.caloriesLabel, isNull);
  });

  test('chi tiết: dinh dưỡng thật', () {
    final r = Recipe.fromDetailJson(detail(calories: 170, nutrition: {'calories': 170.0, 'proteinGrams': 8.0}));
    expect(r.caloriesLabel, '170 kcal');
    expect(r.hasNutrition, isTrue);
  });

  test('thẻ món và danh mục đọc calo ước tính', () {
    final card = RecipeSummary.fromJson({'id': 1, 'title': 'Gỏi', 'category': 'Gỏi & Salad', 'calories': 470, 'caloriesEstimated': true, 'ingredientCount': 8});
    expect(card.metaLabel, 'Gỏi & Salad · 8 nguyên liệu · ~470 kcal');

    final recipes = RecipeRepository.decode([
      {'id': 1000001, 'title': 'A', 'category': 'c', 'time': 0, 'servings': 0, 'nutrients': {}, 'estimatedCalories': 680, 'steps': ['b1'], 'ingredients': [{'name': 'x', 'amount': 1, 'unit': 'g'}]},
    ]);
    expect(recipes.single.caloriesLabel, '~680 kcal');
  });
}
