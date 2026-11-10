// =============================================================================
// FEATURE: GỢI Ý MÓN ĂN THÔNG MINH (Smart Suggest + Match Score Algorithm)
// =============================================================================
//
// VAI TRÒ
//   Chứa toàn bộ logic của màn "Gợi Ý AI":
//     - 2 chế độ tìm: theo nguyên liệu (tủ lạnh) và theo tên món.
//     - Thuật toán tính điểm khớp nguyên liệu (Match Score).
//     - Sắp xếp kết quả (độ khớp / đánh giá / thời gian / calo).
//
// FLOW TỔNG QUÁT
//   1. Màn hình mở → `SuggestController(initialIngredients: ...)`:
//        - Có truyền nguyên liệu (từ Túi Thần Kỳ) → dùng danh sách đó.
//        - Không truyền → lấy nguyên liệu trong tủ lạnh (PantryController).
//        - Tủ lạnh trống → hiển thị toàn bộ công thức.
//   2. Người dùng đổi chế độ / thêm-xoá nguyên liệu / đổi kiểu sắp xếp
//      → controller cập nhật state → `notifyListeners()` → UI build lại.
//   3. UI gọi `results(query)` để lấy danh sách món cần hiển thị:
//        - Chế độ TÊN MÓN       → `searchByName()` lọc theo tên/danh mục/tag.
//        - Chế độ NGUYÊN LIỆU   → `matchRecipesByIngredients()` chấm điểm.
//      Sau đó áp dụng `_applySorting()`.
//
// THUẬT TOÁN MATCH SCORE (matchRecipesByIngredients)
//   Với mỗi công thức:
//     1. Duyệt từng nguyên liệu của công thức.
//     2. Nguyên liệu được coi là "đã có" nếu tên của nó CHỨA hoặc ĐƯỢC CHỨA
//        trong một nguyên liệu người dùng nhập (so sánh không phân biệt
//        hoa/thường). VD: "bò" khớp với "Thịt bò".
//     3. Chia vào 2 nhóm: matched (đã có) / missing (cần mua thêm).
//     4. score = số matched / tổng số nguyên liệu  (0.0 → 1.0).
//     5. Chỉ giữ công thức có ít nhất 1 nguyên liệu khớp.
//   Cuối cùng sắp xếp giảm dần theo score → món tận dụng tủ lạnh tốt nhất
//   đứng đầu.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/recipe_repository.dart';
import '../../core/models/recipe.dart';
import '../kitchen_bag/pantry_controller.dart';

/// Chế độ tìm kiếm của màn Gợi ý.
enum SuggestSearchMode {
  /// Tìm theo tên món / danh mục / tag.
  byName,

  /// Tìm theo nguyên liệu đang có (tủ lạnh) — mặc định.
  byIngredients,
}

/// Tiêu chí sắp xếp kết quả.
enum SuggestSortMode {
  /// Độ khớp nguyên liệu cao nhất (chỉ có ý nghĩa ở chế độ nguyên liệu).
  match,

  /// Điểm đánh giá trung bình cao nhất.
  rating,

  /// Thời gian nấu ngắn nhất.
  time,

  /// Lượng calo thấp nhất.
  calories,
}

class SuggestController extends ChangeNotifier {
  /// Gợi ý nhanh hiển thị dạng chip để thêm nguyên liệu bằng 1 chạm.
  static List<String> get quickSuggestions => RecipeRepository.instance.ingredients.take(12).toList();

  SuggestController({List<String>? initialIngredients}) {
    // Bước 1 của flow: chọn nguồn nguyên liệu ban đầu.
    if (initialIngredients != null && initialIngredients.isNotEmpty) {
      _selectedIngredients.addAll(initialIngredients);
      _searchMode = SuggestSearchMode.byIngredients;
    } else {
      final pantry = PantryController.instance.ingredients;
      _selectedIngredients.addAll(pantry);
    }
  }

  SuggestSearchMode _searchMode = SuggestSearchMode.byIngredients;
  SuggestSortMode _sortMode = SuggestSortMode.match;
  final List<String> _selectedIngredients = [];

  SuggestSearchMode get searchMode => _searchMode;
  SuggestSortMode get sortMode => _sortMode;
  List<String> get selectedIngredients => List.unmodifiable(_selectedIngredients);

  bool get isIngredientMode => _searchMode == SuggestSearchMode.byIngredients;

  // ---------------------------------------------------------------------------
  // HÀNH ĐỘNG TỪ UI
  // ---------------------------------------------------------------------------

  void setSearchMode(SuggestSearchMode mode) {
    _searchMode = mode;
    notifyListeners();
  }

  void setSortMode(SuggestSortMode mode) {
    _sortMode = mode;
    notifyListeners();
  }

  bool isSelected(String ingredient) => _selectedIngredients.contains(ingredient);

  /// Thêm nguyên liệu (bỏ qua nếu rỗng hoặc trùng). Trả về `true` nếu đã thêm,
  /// UI dùng giá trị này để quyết định có xoá ô nhập hay không.
  bool addIngredient(String name) {
    final clean = name.trim();
    if (clean.isEmpty || _selectedIngredients.contains(clean)) return false;

    _selectedIngredients.add(clean);
    notifyListeners();
    return true;
  }

  void removeIngredient(String name) {
    _selectedIngredients.remove(name);
    notifyListeners();
  }

  void clearIngredients() {
    _selectedIngredients.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // KẾT QUẢ
  // ---------------------------------------------------------------------------

  /// Danh sách món cần hiển thị theo chế độ + kiểu sắp xếp hiện tại.
  /// [nameQuery] là nội dung ô tìm kiếm (chỉ dùng ở chế độ tên món).
  List<Recipe> results(String nameQuery) {
    final recipes = RecipeRepository.instance.all;
    final list = isIngredientMode
        ? matchRecipesByIngredients(recipes, _selectedIngredients)
        : searchByName(recipes, nameQuery);
    return _applySorting(list);
  }

  /// Lọc công thức có tên / danh mục / tag chứa [query] (không phân biệt
  /// hoa/thường). Query rỗng → trả về toàn bộ.
  static List<Recipe> searchByName(List<Recipe> recipes, String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return recipes;

    return recipes.where((r) {
      final titleMatch = r.title.toLowerCase().contains(q);
      final catMatch = r.category.toLowerCase().contains(q);
      final tagMatch = r.tags.any((t) => t.toLowerCase().contains(q));
      return titleMatch || catMatch || tagMatch;
    }).toList();
  }

  /// Thuật toán Match Score — xem mô tả chi tiết ở đầu file.
  ///
  /// Trả về bản sao các công thức đã gắn `matchScore`, `matchedIngredients`,
  /// `missingIngredients`, sắp xếp giảm dần theo điểm.
  /// Nếu [userIngredients] rỗng → trả về toàn bộ công thức (không chấm điểm).
  static List<Recipe> matchRecipesByIngredients(
    List<Recipe> recipes,
    List<String> userIngredients,
  ) {
    if (userIngredients.isEmpty) return recipes;

    final lowerInputs = userIngredients.map((e) => e.toLowerCase().trim()).toList();
    final List<Recipe> scoredList = [];

    for (final recipe in recipes) {
      final List<String> matched = [];
      final List<String> missing = [];

      // Bước 1-3: phân loại từng nguyên liệu vào matched / missing.
      for (final ing in recipe.ingredients) {
        final ingNameLower = ing.name.toLowerCase();
        final isHit = lowerInputs.any(
          (userIng) => ingNameLower.contains(userIng) || userIng.contains(ingNameLower),
        );

        if (isHit) {
          matched.add(ing.name);
        } else {
          missing.add(ing.name);
        }
      }

      // Bước 4: tính điểm khớp.
      final total = recipe.ingredients.length;
      final score = total > 0 ? matched.length / total : 0.0;

      // Bước 5: chỉ giữ món có ít nhất 1 nguyên liệu khớp.
      if (matched.isNotEmpty) {
        scoredList.add(recipe.copyWith(
          matchScore: score,
          matchedIngredients: matched,
          missingIngredients: missing,
        ));
      }
    }

    // Sắp xếp: điểm cao nhất lên đầu.
    scoredList.sort((a, b) => (b.matchScore ?? 0).compareTo(a.matchScore ?? 0));
    return scoredList;
  }

  /// Sắp xếp theo tiêu chí người dùng chọn. Luôn tạo list mới, không sửa input.
  List<Recipe> _applySorting(List<Recipe> input) {
    final list = List<Recipe>.from(input);
    switch (_sortMode) {
      case SuggestSortMode.rating:
        list.sort((a, b) => b.averageRating.compareTo(a.averageRating));
      case SuggestSortMode.time:
        list.sort((a, b) => a.cookTimeMinutes.compareTo(b.cookTimeMinutes));
      case SuggestSortMode.calories:
        list.sort((a, b) => a.calories.compareTo(b.calories));
      case SuggestSortMode.match:
        // Ở chế độ tên món không có điểm khớp → giữ thứ tự gốc.
        if (isIngredientMode) {
          list.sort((a, b) => (b.matchScore ?? 0).compareTo(a.matchScore ?? 0));
        }
    }
    return list;
  }
}
