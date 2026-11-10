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
  Recipe findById(int id) => all.firstWhere((r) => r.id == id);

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
