// =============================================================================
// MODEL: THẺ MÓN (RecipeSummary) & TRANG KẾT QUẢ (RecipePage)
// =============================================================================
//
// Dữ liệu nhẹ để vẽ thẻ món ở Home/danh mục, đọc từ `GET /api/Recipes/page`
// (`RecipeCardDto` phía Rust). Không có nguyên liệu, các bước → mỗi trang chỉ
// vài KB. Mở chi tiết thì tải đầy đủ theo id.
//
// `cookTimeMinutes` / `calories` = 0 nghĩa là "không rõ" (món Việt cào từ web).
// `cookTimeEstimated` = thời gian ước lượng từ nội dung các bước → hiện "~".
// =============================================================================

import 'calories_format.dart';
import 'cook_time_format.dart';
import 'recipe.dart';

class RecipeSummary {
  final int id;
  final String title;
  final String image;
  final String category;
  final String source;
  final int cookTimeMinutes;
  final bool cookTimeEstimated;
  final int calories;

  /// true = calo ước tính từ nguyên liệu cho cả món (hiện "~").
  final bool caloriesEstimated;
  final int ingredientCount;

  const RecipeSummary({
    required this.id,
    required this.title,
    required this.image,
    required this.category,
    required this.source,
    required this.cookTimeMinutes,
    this.cookTimeEstimated = false,
    required this.calories,
    this.caloriesEstimated = false,
    required this.ingredientCount,
  });

  factory RecipeSummary.fromJson(Map<String, dynamic> json) => RecipeSummary(
    id: json['id'] as int,
    title: json['title'] as String,
    image: json['image'] as String? ?? '',
    category: json['category'] as String? ?? '',
    source: json['source'] as String? ?? '',
    cookTimeMinutes: json['cookTimeMinutes'] as int? ?? 0,
    cookTimeEstimated: json['cookTimeEstimated'] as bool? ?? false,
    calories: json['calories'] as int? ?? 0,
    caloriesEstimated: json['caloriesEstimated'] as bool? ?? false,
    ingredientCount: json['ingredientCount'] as int? ?? 0,
  );

  /// Dùng khi không gọi được server: tạo thẻ từ công thức đầy đủ có sẵn.
  factory RecipeSummary.fromRecipe(Recipe r) => RecipeSummary(
    id: r.id,
    title: r.title,
    image: r.imageAsset,
    category: r.category,
    source: r.description.replaceFirst('Nguồn: ', ''),
    cookTimeMinutes: r.cookTimeMinutes,
    cookTimeEstimated: r.cookTimeEstimated,
    calories: r.calories,
    caloriesEstimated: r.caloriesEstimated,
    ingredientCount: r.ingredients.length,
  );

  /// Dòng phụ dưới tên món: "Canh · 9 nguyên liệu · 320 kcal".
  String get metaLabel => [
    if (category.isNotEmpty) category,
    if (ingredientCount > 0) '$ingredientCount nguyên liệu',
    ?formatCalories(calories, estimated: caloriesEstimated),
    ?formatCookTime(cookTimeMinutes, estimated: cookTimeEstimated),
  ].join(' · ');
}

class RecipePage {
  final List<RecipeSummary> items;
  final int page;
  final int total;
  final bool hasMore;

  const RecipePage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasMore,
  });

  factory RecipePage.fromJson(Map<String, dynamic> json) => RecipePage(
    items: [
      for (final x in json['items'] as List)
        RecipeSummary.fromJson(x as Map<String, dynamic>),
    ],
    page: json['page'] as int,
    total: json['total'] as int,
    hasMore: json['hasMore'] as bool,
  );
}

/// Danh mục kèm số món, từ `GET /api/Recipes/categories`.
class CategoryCount {
  final String name;
  final int count;

  const CategoryCount(this.name, this.count);

  factory CategoryCount.fromJson(Map<String, dynamic> json) =>
      CategoryCount(json['name'] as String, json['count'] as int);
}
