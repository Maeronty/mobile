// =============================================================================
// RECIPE REPOSITORY — Kho công thức dùng chung cho toàn app
// =============================================================================
//
// VAI TRÒ
//   Nguồn dữ liệu duy nhất cho danh sách công thức. Home, Gợi ý, Yêu thích,
//   Thực đơn... đều đọc qua đây.
//
// NGUỒN DỮ LIỆU (giống seed của backend Rust)
//   - 8 món Spoonacular (đã dịch tiếng Việt), id < 1.000.000.
//   - ~1.800 món Việt cào từ Món Ngon Mỗi Ngày, id ≥ 1.000.000
//     (`backend/assets/vietnamese_recipes.json`, tạo bởi tools/import_monngon.py).
//
// AI DÙNG KHO NÀY
//   Home / danh mục / chi tiết KHÔNG dùng kho này nữa — chúng gọi API phân trang
//   (xem recipe_feed_source.dart). Kho chỉ phục vụ Gợi ý theo nguyên liệu,
//   Surprise Me, Tủ lạnh, Yêu thích, Thực đơn, và làm dữ liệu dự phòng offline.
//   main() bắt đầu tải NGẦM, không chờ → app mở ngay. Tải xong →
//   notifyListeners() để các màn đang hiển thị dựng lại.
//
// FLOW (`load`)
//   1. Gọi `GET /catalog` của backend Rust, chờ tối đa 5 giây.
//   2. Thành công → dùng danh mục từ server.
//   3. Lỗi bất kỳ (server tắt, mất mạng, JSON sai kiểu...) → đọc 2 file JSON
//      đóng gói sẵn trong app. Bắt mọi lỗi, không chỉ Exception, để dữ liệu
//      hỏng không làm app trắng màn hình lúc khởi động.
//   4. Sắp xếp: món Việt trước, rồi đến món Spoonacular.
//
// DỮ LIỆU "KHÔNG RÕ"
//   Món Việt không có thời gian nấu, khẩu phần, dinh dưỡng → `time`/`servings`
//   = 0 và `nutrients` rỗng. Ở đây giữ 0, giao diện hiện "—"
//   (xem các getter `hasCookTime`, `caloriesLabel`... trong model Recipe).
//
// LƯU Ý
//   `findById` không thấy id → trả món đầu tiên thay vì crash màn chi tiết.
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import 'api_client.dart';

class RecipeRepository extends ChangeNotifier {
  RecipeRepository._();
  static final instance = RecipeRepository._();

  /// Id của món Việt bắt đầu từ đây (khớp `VIETNAMESE_ID_BASE` phía Rust).
  static const int vietnameseIdBase = 1000000;

  static const _bundledFiles = [
    'backend/assets/vietnamese_recipes.json',
    'assets/spoonacular.json',
  ];

  List<Recipe> _recipes = [];
  Future<void>? _loading;

  /// Đã có dữ liệu (từ server hoặc file đóng gói).
  bool get isLoaded => _recipes.isNotEmpty;

  /// Tải nếu chưa tải; nhiều nơi gọi cùng lúc chỉ tải một lần.
  Future<void> ensureLoaded() => isLoaded ? Future.value() : (_loading ??= load());
  List<Recipe> get all => _recipes;

  /// Danh mục sắp theo số món giảm dần; "Món khác" luôn đứng cuối.
  List<String> get categories {
    final counts = <String, int>{};
    for (final r in all) {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    }
    final list = counts.keys.toList()
      ..sort((a, b) {
        if (a == otherCategory) return 1;
        if (b == otherCategory) return -1;
        return counts[b]!.compareTo(counts[a]!);
      });
    return list;
  }

  static const String otherCategory = 'Món khác';
  List<String> get ingredients =>
      all.expand((r) => r.ingredients).map((i) => i.name).toSet().toList();
  Recipe findById(int id) =>
      all.firstWhere((r) => r.id == id, orElse: () => all.first);

  Future<void> load({bool online = true}) async {
    if (online) {
      try {
        final data = await ApiClient.instance.get(
          '/catalog',
          timeout: const Duration(seconds: 5),
        );
        _recipes = _sorted(decode(data as List));
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('RecipeRepository: dùng danh mục có sẵn ($e)');
      }
    }
    final rows = <dynamic>[];
    for (final file in _bundledFiles) {
      rows.addAll(jsonDecode(await rootBundle.loadString(file)) as List);
    }
    _recipes = _sorted(decode(rows));
    notifyListeners();
  }

  List<Recipe> _sorted(List<Recipe> recipes) {
    final list = [...recipes]
      ..sort((a, b) {
        final aViet = a.id >= vietnameseIdBase;
        final bViet = b.id >= vietnameseIdBase;
        if (aViet != bViet) return aViet ? -1 : 1;
        return a.id.compareTo(b.id);
      });
    return List.unmodifiable(list);
  }

  /// Chuyển JSON dạng `/catalog` thành Recipe. Public để test.
  @visibleForTesting
  static List<Recipe> decode(List rows) {
    if (rows.isEmpty) throw const FormatException('Danh mục trống');
    double num0(Object? v) => (v as num?)?.toDouble() ?? 0;
    return rows.map((r) {
      final n = (r['nutrients'] as Map?) ?? const {};
      final fiber = n['Fiber'] as num?;
      final nutrition = NutritionInfo(
        calories: num0(n['Calories']).round(),
        proteinGrams: num0(n['Protein']),
        carbsGrams: num0(n['Carbohydrates']),
        fatGrams: num0(n['Fat']),
        fiberGrams: fiber == null || fiber <= 0 ? null : fiber.toDouble(),
      );
      final steps = (r['steps'] as List).cast<String>();
      final source = r['source'] as String? ?? 'Spoonacular';
      final raw = (r['category'] as String).trim();
      // Spoonacular trả danh mục viết thường ("món ăn kèm") → viết hoa chữ đầu.
      final category = raw.isEmpty
          ? otherCategory
          : raw[0].toUpperCase() + raw.substring(1);
      return Recipe(
        id: r['id'] as int,
        title: r['title'] as String,
        imageAsset: r['image'] as String? ?? '',
        description: 'Nguồn: $source',
        category: category,
        tags: [category],
        cookTimeMinutes: (r['time'] as int?) ?? 0,
        servings: (r['servings'] as int?) ?? 0,
        difficulty: steps.length <= 4
            ? 'Dễ'
            : steps.length <= 8
            ? 'Trung bình'
            : 'Khó',
        calories: nutrition.calories,
        nutrition: nutrition,
        averageRating: 0,
        totalRatings: 0,
        ingredients: [
          for (final i in r['ingredients'])
            IngredientItem(
              name: i['name'] as String,
              amount: num0(i['amount']),
              unit: i['unit'] as String? ?? '',
            ),
        ],
        instructions: [
          for (final (index, step) in steps.indexed)
            InstructionStep(stepNumber: index + 1, description: step),
        ],
      );
    }).toList();
  }
}
