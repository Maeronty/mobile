import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/recipe.dart';

class RecipeRepository {
  RecipeRepository._();
  static final instance = RecipeRepository._();
  static const apiBase = String.fromEnvironment('FOOD_API_URL',
      defaultValue: 'http://127.0.0.1:8787');

  List<Recipe> _recipes = [];
  List<Recipe> get all => _recipes;
  List<String> get categories => all.map((r) => r.category).toSet().toList();
  List<String> get ingredients => all.expand((r) => r.ingredients)
      .map((i) => i.name).toSet().toList();

  Recipe? findByIdOrNull(int id) {
    for (final r in _recipes) {
      if (r.id == id) return r;
    }
    return null;
  }

  void addRecipe(Recipe recipe) {
    if (!_recipes.any((r) => r.id == recipe.id)) {
      _recipes = [..._recipes, recipe];
    }
  }

  Recipe createCompatibleRecipe({
    required int id,
    required String title,
    String? description,
    String? imageAsset,
    List<String> used = const [],
    List<String> missing = const [],
  }) {
    final List<IngredientItem> ingItems = [];
    for (final u in used) {
      if (u.trim().isNotEmpty) {
        ingItems.add(IngredientItem(
          name: u.trim(),
          amount: 1.0,
          unit: 'phần',
          note: 'Đã có sẵn',
        ));
      }
    }
    for (final m in missing) {
      if (m.trim().isNotEmpty) {
        ingItems.add(IngredientItem(
          name: m.trim(),
          amount: 1.0,
          unit: 'phần',
          note: 'Cần chuẩn bị thêm',
        ));
      }
    }
    if (ingItems.isEmpty) {
      ingItems.add(const IngredientItem(
        name: 'Nguyên liệu chính',
        amount: 1.0,
        unit: 'phần',
      ));
    }

    final totalIngs = used.length + missing.length;
    final matchScore = totalIngs > 0 ? used.length / totalIngs : 1.0;

    final img = imageAsset?.isNotEmpty == true
        ? imageAsset!
        : 'https://img.spoonacular.com/recipes/$id-312x231.jpg';

    return Recipe(
      id: id,
      title: title,
      description: description ?? 'Công thức được đề xuất bởi Bếp Việt AI.',
      imageAsset: img,
      category: 'Món chính',
      tags: const ['Gợi ý AI', 'Món chính'],
      cookTimeMinutes: 25,
      difficulty: 'Dễ',
      servings: 2,
      calories: 450,
      averageRating: 4.8,
      totalRatings: 15,
      isFavorited: false,
      ingredients: ingItems,
      instructions: const [
        InstructionStep(
          stepNumber: 1,
          description: 'Sơ chế và rửa sạch các nguyên liệu đã chuẩn bị.',
          estimatedMinutes: 5,
          tip: 'Để ráo nước trước khi tiến hành chế biến.',
        ),
        InstructionStep(
          stepNumber: 2,
          description: 'Nêm nếm gia vị và tiến hành nấu chín theo khẩu vị gia đình.',
          estimatedMinutes: 15,
          tip: 'Giữ lửa vừa để món ăn chín đều và dậy mùi thơm.',
        ),
        InstructionStep(
          stepNumber: 3,
          description: 'Bày món ăn ra đĩa, trang trí và thưởng thức khi còn nóng.',
          estimatedMinutes: 5,
          tip: 'Ăn kèm cơm nóng hoặc rau thơm để tăng hương vị.',
        ),
      ],
      nutrition: const NutritionInfo(
        calories: 450,
        proteinGrams: 22.0,
        carbsGrams: 42.0,
        fatGrams: 14.0,
      ),
      matchScore: matchScore,
      matchedIngredients: used,
      missingIngredients: missing,
    );
  }

  Recipe findById(int id) {
    final existing = findByIdOrNull(id);
    if (existing != null) return existing;

    final fallback = createCompatibleRecipe(
      id: id,
      title: 'Món ngon #$id',
      description: 'Công thức được tạo tự động bởi Bếp Việt AI.',
    );
    addRecipe(fallback);
    return fallback;
  }

  Future<void> load({bool online = true}) async {
    if (online) {
      try {
        final response = await http.get(Uri.parse('$apiBase/catalog'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _recipes = _decode(utf8.decode(response.bodyBytes));
          return;
        }
      } on Exception {
        // The bundled catalog is a Vietnamese snapshot of the same API.
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
