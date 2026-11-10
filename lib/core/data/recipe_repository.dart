// =============================================================================
// RECIPE REPOSITORY — Kho công thức dùng chung cho toàn app
// =============================================================================
//
// VAI TRÒ
//   Nguồn dữ liệu duy nhất cho danh sách công thức (danh mục Spoonacular đã
//   dịch tiếng Việt). Home, Gợi ý, Yêu thích, Thực đơn... đều đọc qua đây.
//
// FLOW (`load`, gọi trong main trước khi vẽ giao diện)
//   1. Gọi `GET /catalog` của backend Rust, chờ tối đa 3 giây.
//   2. Thành công → dùng danh mục từ server.
//   3. Lỗi bất kỳ (server tắt, mất mạng, JSON sai kiểu...) → dùng bản tiếng
//      Việt có sẵn `assets/spoonacular.json`. Bắt mọi lỗi, không chỉ Exception,
//      để dữ liệu hỏng từ server không làm app trắng màn hình lúc khởi động.
//
// LƯU Ý
//   `findById` không thấy id → trả món đầu tiên thay vì crash màn chi tiết.
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import 'api_client.dart';

class RecipeRepository {
  RecipeRepository._();
  static final instance = RecipeRepository._();

  List<Recipe> _recipes = [];
  List<Recipe> get all => _recipes;
  List<String> get categories => all.map((r) => r.category).toSet().toList();
  List<String> get ingredients => all.expand((r) => r.ingredients)
      .map((i) => i.name).toSet().toList();
  Recipe findById(int id) => all.firstWhere((r) => r.id == id, orElse: () => all.first);

  Future<void> load({bool online = true}) async {
    if (online) {
      try {
        final data = await ApiClient.instance.get('/catalog', timeout: const Duration(seconds: 3));
        _recipes = _decode(jsonEncode(data));
        return;
      } catch (e) {
        debugPrint('RecipeRepository: dùng danh mục có sẵn ($e)');
      }
    }
    _recipes = _decode(await rootBundle.loadString('assets/spoonacular.json'));
  }

  List<Recipe> _decode(String text) {
    final rows = jsonDecode(text) as List;
    if (rows.isEmpty) throw const FormatException('Danh mục trống');
    return List.unmodifiable(rows.map((r) {
      final n = r['nutrients'] as Map;
      final nutrition = NutritionInfo(calories: (n['Calories'] as num).round(),
          proteinGrams: (n['Protein'] as num).toDouble(),
          carbsGrams: (n['Carbohydrates'] as num).toDouble(),
          fatGrams: (n['Fat'] as num).toDouble());
      final steps = (r['steps'] as List).cast<String>();
      return Recipe(id: r['id'], title: r['title'], imageAsset: r['image'] ?? '',
          description: 'Spoonacular · ${r['source']}', category: r['category'],
          tags: [r['category']], cookTimeMinutes: r['time'], servings: r['servings'],
          difficulty: steps.length <= 4 ? 'Dễ' : steps.length <= 8 ? 'Trung bình' : 'Khó',
          calories: nutrition.calories, nutrition: nutrition, averageRating: 0, totalRatings: 0,
          ingredients: [for (final i in r['ingredients']) IngredientItem(name: i['name'],
              amount: (i['amount'] as num).toDouble(), unit: i['unit'])],
          instructions: [for (final (index, step) in steps.indexed)
              InstructionStep(stepNumber: index + 1, description: step)]);
    }));
  }
}
