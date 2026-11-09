// =============================================================================
// RECIPE REPOSITORY — Kho công thức dùng chung cho toàn app
// =============================================================================
//
// VAI TRÒ
//   Là nguồn dữ liệu (single source of truth) duy nhất cho danh sách công thức.
//   Mọi feature (Home, Gợi ý, Yêu thích, Chi tiết...) đều đọc công thức qua đây
//   thay vì truy cập trực tiếp MockData → sau này đổi sang API/DB chỉ cần sửa
//   file này.
//
// FLOW
//   1. Lần đầu gọi `RecipeRepository.instance` → constructor copy danh sách
//      công thức từ MockData vào bộ nhớ.
//   2. Feature khác gọi `all` để lấy toàn bộ, hoặc `findById` để lấy 1 món.
//
// LƯU Ý
//   - Dữ liệu chỉ đọc (read-only), không có thao tác thêm/sửa/xoá nên không
//     cần ChangeNotifier.
// =============================================================================

import '../models/recipe.dart';
import 'mock_data.dart';

class RecipeRepository {
  /// Singleton: cả app dùng chung một kho công thức.
  static final RecipeRepository instance = RecipeRepository._();

  RecipeRepository._() : _recipes = List.unmodifiable(MockData.recipes);

  final List<Recipe> _recipes;

  /// Toàn bộ công thức hiện có.
  List<Recipe> get all => _recipes;

  /// Tìm công thức theo [id].
  ///
  /// Nếu không tìm thấy (id sai / dữ liệu bị xoá) thì trả về món đầu tiên
  /// để màn hình chi tiết không bị crash — giữ nguyên hành vi cũ của app.
  Recipe findById(int id) {
    return _recipes.firstWhere(
      (r) => r.id == id,
      orElse: () => _recipes.first,
    );
  }
}
