// =============================================================================
// FEATURE: MÓN ĂN YÊU THÍCH (Favorites)
// =============================================================================
//
// VAI TRÒ
//   Quản lý danh sách id các công thức người dùng đã thả tim.
//
// FLOW
//   1. Khởi tạo với vài món yêu thích mẫu (id 1, 2, 4, 8).
//   2. Người dùng bấm icon trái tim trên RecipeCard hoặc màn Chi tiết
//      → `toggleFavorite(recipeId)`:
//        - Đã có trong danh sách  → xoá (bỏ thích).
//        - Chưa có               → thêm (thích).
//   3. `notifyListeners()` → widget đang lắng nghe build lại icon trái tim.
//   4. Tab "Đã Lưu" của Túi Thần Kỳ gọi `favoriteRecipes` để hiển thị lưới món.
//
// THIẾT KẾ
//   - Chỉ lưu `Set<int>` id (không lưu cả object Recipe) → tra cứu O(1) và
//     không bị lệch dữ liệu khi công thức gốc thay đổi.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/recipe_repository.dart';
import '../../core/models/recipe.dart';

class FavoritesController extends ChangeNotifier {
  /// Singleton: danh sách yêu thích dùng chung giữa các màn hình.
  static final FavoritesController instance = FavoritesController._();

  FavoritesController._();

  /// Id các món yêu thích mặc định khi mở app (dữ liệu demo).
  final Set<int> _favoriteIds = {};

  /// Bản chỉ đọc của tập id yêu thích.
  Set<int> get favoriteIds => Set.unmodifiable(_favoriteIds);

  /// Kiểm tra một công thức có đang được yêu thích không.
  bool isFavorite(int recipeId) => _favoriteIds.contains(recipeId);

  /// Danh sách công thức yêu thích, giữ đúng thứ tự trong kho công thức.
  List<Recipe> get favoriteRecipes {
    return RecipeRepository.instance.all
        .where((r) => _favoriteIds.contains(r.id))
        .toList();
  }

  /// Thả tim / bỏ thả tim cho công thức [recipeId].
  void toggleFavorite(int recipeId) {
    if (_favoriteIds.contains(recipeId)) {
      _favoriteIds.remove(recipeId);
    } else {
      _favoriteIds.add(recipeId);
    }
    notifyListeners();
  }
}
