// Test dữ liệu món Việt (backend/assets/vietnamese_recipes.json) trong app:
// đọc được, không bịa dữ liệu thiếu, Home chỉ hiện một phần và "Xem thêm".

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tomato_food_tip/core/data/api_client.dart';
import 'package:tomato_food_tip/core/data/recipe_feed_source.dart';
import 'package:tomato_food_tip/core/data/recipe_repository.dart';
import 'package:tomato_food_tip/features/recipe_detail/recipe_detail_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('đọc món Việt không có dinh dưỡng / thời gian / khẩu phần mà không bịa số', () {
    final rows = jsonDecode(File('backend/assets/vietnamese_recipes.json').readAsStringSync()) as List;
    final recipes = RecipeRepository.decode(rows);
    expect(recipes.length, rows.length);

    final pho = recipes.firstWhere((r) => r.title.contains('Phở'));
    expect(pho.hasNutrition, isFalse);
    expect(pho.caloriesLabel, isNull, reason: 'file đóng gói chưa có calo ước tính → ẩn'); 
    expect(pho.cookTimeLabel, isNull, reason: 'không rõ thời gian → ẩn, không hiện "— phút"');
    expect(pho.description, 'Nguồn: Món Ngon Mỗi Ngày');
    expect(pho.ingredients, isNotEmpty);
    expect(pho.instructions, isNotEmpty);
  });

  test('chất xơ được đọc khi có dữ liệu', () {
    final recipes = RecipeRepository.decode([
      {
        'id': 1, 'title': 'A', 'image': null, 'source': 'S', 'category': 'c', 'time': 20, 'servings': 2,
        'nutrients': {'Calories': 100, 'Protein': 5, 'Carbohydrates': 10, 'Fat': 2, 'Fiber': 3.5},
        'steps': ['b1'], 'ingredients': [{'name': 'x', 'amount': 1, 'unit': 'g'}],
      },
    ]);
    expect(recipes.single.nutrition.fiberGrams, 3.5);
    expect(recipes.single.caloriesLabel, '100 kcal');
  });

  test('offline: món Việt đứng trước, nguồn dự phòng phân trang và lọc danh mục được', () async {
    await RecipeRepository.instance.load(online: false);
    final all = RecipeRepository.instance.all;
    expect(all.length, greaterThan(1500));
    expect(all.first.id, greaterThanOrEqualTo(RecipeRepository.vietnameseIdBase));

    final local = LocalRecipeFeedSource();
    final first = await local.page(page: 1, pageSize: 20);
    expect(first.items, hasLength(20));
    expect(first.hasMore, isTrue);
    final canh = await local.page(page: 1, pageSize: 20, category: 'Canh');
    expect(canh.items.every((r) => r.category == 'Canh'), isTrue);
    final featured = await local.featured();
    expect(featured.map((r) => r.category).toSet().length, featured.length, reason: 'mỗi banner một danh mục');
    expect((await local.categories()).last.name, 'Món khác');
  });

  test('chi tiết không gọi được server → lấy từ dữ liệu có sẵn; định lượng giữ như gốc', () async {
    await RecipeRepository.instance.load(online: false);
    final viet = RecipeRepository.instance.all.firstWhere((r) => r.ingredients.any((i) => i.amount == 0));
    final offlineApi = ApiClient(baseUrl: 'http://test', client: MockClient((_) async => http.Response('', 500)));
    final c = RecipeDetailController(recipeId: viet.id, api: offlineApi);
    while (c.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.recipe?.id, viet.id);
    expect(c.formatAmount(0), '');
    expect(c.formatAmount(150), '150');
    expect(c.formatAmount(1.5), '1.5');
    c.dispose();
  });
}
