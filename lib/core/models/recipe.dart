class IngredientItem {
  final String name;
  final double amount;
  final String unit;
  final String? note;

  const IngredientItem({
    required this.name,
    required this.amount,
    required this.unit,
    this.note,
  });

  IngredientItem copyWithScaled(double scaleFactor) {
    return IngredientItem(
      name: name,
      amount: (amount * scaleFactor),
      unit: unit,
      note: note,
    );
  }
}

class InstructionStep {
  final int stepNumber;
  final String description;
  final int? estimatedMinutes;
  final String? tip;

  const InstructionStep({
    required this.stepNumber,
    required this.description,
    this.estimatedMinutes,
    this.tip,
  });
}

class NutritionInfo {
  final int calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double? fiberGrams;

  const NutritionInfo({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    this.fiberGrams,
  });
}

class Recipe {
  final int id;
  final String title;
  final String description;
  final String imageAsset;
  final String category;
  final List<String> tags;
  final int cookTimeMinutes;
  final String difficulty; // "Dễ", "Trung bình", "Khó"
  final int servings;
  final int calories;
  final double averageRating;
  final int totalRatings;
  final bool isFavorited;
  final List<IngredientItem> ingredients;
  final List<InstructionStep> instructions;
  final NutritionInfo nutrition;
  final double? matchScore;
  final List<String> matchedIngredients;
  final List<String> missingIngredients;

  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.category,
    required this.tags,
    required this.cookTimeMinutes,
    required this.difficulty,
    required this.servings,
    required this.calories,
    required this.averageRating,
    required this.totalRatings,
    this.isFavorited = false,
    required this.ingredients,
    required this.instructions,
    required this.nutrition,
    this.matchScore,
    this.matchedIngredients = const [],
    this.missingIngredients = const [],
  });

  /// Đọc JSON của `GET /api/Recipes/:id` (RecipeDetailDto phía Rust).
  /// Thiếu dinh dưỡng → các chỉ số = 0 (hiển thị "—"); độ khó "Nâng cao" → "Khó".
  factory Recipe.fromDetailJson(Map<String, dynamic> json) {
    double num0(Object? v) => (v as num?)?.toDouble() ?? 0;
    final n = json['nutrition'] as Map<String, dynamic>?;
    final cookTime = json['cookTimeMinutes'] as int? ?? 0;
    final fiber = num0(n?['fiberGrams']);
    final tags = [for (final t in (json['tags'] as List? ?? const [])) t as String];
    final difficulty = json['difficulty'] as String? ?? 'Trung bình';
    final nutrition = NutritionInfo(
      calories: num0(n?['calories']).round(),
      proteinGrams: num0(n?['proteinGrams']),
      carbsGrams: num0(n?['carbsGrams']),
      fatGrams: num0(n?['fatGrams']),
      fiberGrams: fiber > 0 ? fiber : null,
    );
    final source = json['source'] as String?;
    return Recipe(
      id: json['id'] as int,
      title: json['title'] as String,
      description: source == null || source.isEmpty ? (json['description'] as String? ?? '') : 'Nguồn: $source',
      imageAsset: json['imageUrl'] as String? ?? '',
      category: tags.isNotEmpty ? tags.first : '',
      tags: tags,
      cookTimeMinutes: cookTime,
      difficulty: difficulty == 'Nâng cao' ? 'Khó' : difficulty,
      servings: json['servings'] as int? ?? 0,
      calories: nutrition.calories,
      averageRating: num0(json['averageRating']),
      totalRatings: json['totalRatings'] as int? ?? 0,
      isFavorited: json['isFavorited'] as bool? ?? false,
      nutrition: nutrition,
      ingredients: [
        for (final i in json['ingredients'] as List)
          IngredientItem(
            name: i['name'] as String,
            amount: num0(i['amount']),
            unit: i['unit'] as String? ?? '',
            note: i['notes'] as String?,
          ),
      ],
      instructions: [
        for (final s in json['instructions'] as List)
          InstructionStep(
            stepNumber: s['stepNumber'] as int,
            description: s['content'] as String,
            // Server tự chia đều thời gian nấu cho các bước; món không rõ thời
            // gian (0) thì con số đó vô nghĩa → bỏ.
            estimatedMinutes: cookTime > 0 ? s['estimatedMinutes'] as int? : null,
          ),
      ],
    );
  }

  // Dữ liệu cào từ Món Ngon Mỗi Ngày không có thời gian nấu, khẩu phần và dinh
  // dưỡng → lưu 0 = "không rõ". Giao diện dùng các getter dưới đây để hiện "—"
  // thay vì số 0 sai.
  bool get hasCookTime => cookTimeMinutes > 0;
  bool get hasServings => servings > 0;
  bool get hasNutrition => calories > 0;
  String get cookTimeLabel => hasCookTime ? '$cookTimeMinutes phút' : '— phút';
  String get cookTimeShortLabel => hasCookTime ? '${cookTimeMinutes}p' : '—';
  String get caloriesLabel => hasNutrition ? '$calories kcal' : '— kcal';
  String get servingsLabel => hasServings ? '$servings người' : '— người';

  Recipe copyWith({
    bool? isFavorited,
    double? matchScore,
    List<String> matchedIngredients = const [],
    List<String> missingIngredients = const [],
  }) {
    return Recipe(
      id: id,
      title: title,
      description: description,
      imageAsset: imageAsset,
      category: category,
      tags: tags,
      cookTimeMinutes: cookTimeMinutes,
      difficulty: difficulty,
      servings: servings,
      calories: calories,
      averageRating: averageRating,
      totalRatings: totalRatings,
      isFavorited: isFavorited ?? this.isFavorited,
      ingredients: ingredients,
      instructions: instructions,
      nutrition: nutrition,
      matchScore: matchScore ?? this.matchScore,
      matchedIngredients: matchedIngredients.isNotEmpty
          ? matchedIngredients
          : this.matchedIngredients,
      missingIngredients: missingIngredients.isNotEmpty
          ? missingIngredients
          : this.missingIngredients,
    );
  }
}
