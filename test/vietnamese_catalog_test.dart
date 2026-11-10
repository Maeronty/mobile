// Test dữ liệu món Việt (backend/assets/vietnamese_recipes.json) trong app:
// đọc được, không bịa dữ liệu thiếu, Home chỉ hiện một phần và "Xem thêm".

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/core/data/recipe_repository.dart';
import 'package:tomato_food_tip/features/home/home_controller.dart';
import 'package:tomato_food_tip/features/recipe_detail/recipe_detail_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('đọc món Việt không có dinh dưỡng / thời gian / khẩu phần mà không bịa số', () {
    final rows = jsonDecode(File('backend/assets/vietnamese_recipes.json').readAsStringSync()) as List;
    final recipes = RecipeRepository.decode(rows);
    expect(recipes.length, rows.length);

    final pho = recipes.firstWhere((r) => r.title.contains('Phở'));
    expect(pho.hasNutrition, isFalse);
    expect(pho.caloriesLabel, '— kcal');
    expect(pho.cookTimeLabel, '— phút');
    expect(pho.servingsLabel, '— người');
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

  test('offline: món Việt đứng trước, Home hiện 20 món và xem thêm được', () async {
    await RecipeRepository.instance.load(online: false);
    final all = RecipeRepository.instance.all;
    expect(all.length, greaterThan(1500));
    expect(all.first.id, greaterThanOrEqualTo(RecipeRepository.vietnameseIdBase));

    final home = HomeController();
    expect(home.visibleRecipes, hasLength(HomeController.pageSize));
    expect(home.hasMore, isTrue);
    home.showMore();
    expect(home.visibleRecipes, hasLength(HomeController.pageSize * 2));

    home.selectCategory('Canh');
    expect(home.visibleRecipes.every((r) => r.category == 'Canh'), isTrue);
    expect(home.visibleRecipes, hasLength(HomeController.pageSize), reason: 'đổi danh mục phải reset số món hiển thị');

    // Không món Việt nào lọt vào "nấu nhanh" chỉ vì thời gian = 0.
    expect(home.fastRecipes.every((r) => r.hasCookTime), isTrue);
    // Banner là món Việt có ảnh, mỗi banner một danh mục.
    final tags = HomeController.heroBanners.map((b) => b['tag']).toList();
    expect(tags.toSet().length, tags.length);
    home.dispose();
  });

  test('chi tiết món không rõ khẩu phần: không nhân định lượng, nguyên liệu không định lượng không hiện số', () async {
    await RecipeRepository.instance.load(online: false);
    final viet = RecipeRepository.instance.all.firstWhere((r) => r.ingredients.any((i) => i.amount == 0));
    final c = RecipeDetailController(recipeId: viet.id);
    expect(c.canScale, isFalse);
    c.increaseServings();
    expect(c.scaleFactor, 1);
    expect(c.formatScaledAmount(0), '');
    expect(c.formatScaledAmount(150), '150');
    c.dispose();
  });
}
