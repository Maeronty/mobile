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
      matchedIngredients: matchedIngredients.isNotEmpty ? matchedIngredients : this.matchedIngredients,
      missingIngredients: missingIngredients.isNotEmpty ? missingIngredients : this.missingIngredients,
    );
  }
}

