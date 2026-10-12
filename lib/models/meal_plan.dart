class MealItem {
  final String mealType; // "Bữa sáng", "Bữa trưa", "Bữa tối", "Bữa phụ"
  final String dishName;
  final String imageAsset;
  final int calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String tip;

  const MealItem({
    required this.mealType,
    required this.dishName,
    required this.imageAsset,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.tip,
  });
}

class DailyPlan {
  final int dayNumber;
  final String dayName; // "Thứ Hai", "Thứ Ba", ...
  final List<MealItem> meals;
  final int totalCalories;
  final String nutritionSummary;

  const DailyPlan({
    required this.dayNumber,
    required this.dayName,
    required this.meals,
    required this.totalCalories,
    required this.nutritionSummary,
  });
}

class MealPlan {
  final String targetGroup; // "Cá nhân", "Cặp đôi", "Gia đình"
  final String healthGoal; // "Cân bằng", "Giảm cân", "Tăng cơ", "Eat Clean"
  final int totalDays;
  final List<DailyPlan> dailyPlans;
  final String advisorAdvice;

  const MealPlan({
    required this.targetGroup,
    required this.healthGoal,
    required this.totalDays,
    required this.dailyPlans,
    required this.advisorAdvice,
  });
}

