// =============================================================================
// FEATURE: MÓN ĂN YÊU THÍCH (Favorites)
// =============================================================================
//
// VAI TRÒ
//   Quản lý danh sách id các công thức người dùng đã thả tim.
//
// FLOW
//   1. Khởi tạo: nạp id từ SharedPreferences; đăng nhập → `syncWithServer`
//      (đẩy id local lên, kéo danh sách server về). Đăng xuất → `clear`.
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
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/api_client.dart';
import '../../core/data/recipe_repository.dart';
import '../../core/models/recipe.dart';

class FavoritesController extends ChangeNotifier {
  static const String _storageKey = 'favorite_recipe_ids';

  /// Singleton: danh sách yêu thích dùng chung giữa các màn hình.
  static final FavoritesController instance = FavoritesController._();

  FavoritesController._() {
    _ready = _loadFromLocal();
  }

  /// Hoàn tất khi đã nạp xong dữ liệu local — mọi thao tác đồng bộ phải chờ.
  late final Future<void> _ready;

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

  /// Chờ nạp local xong rồi đồng bộ server (nếu đã đăng nhập).
  Future<void> init() async {
    await _ready;
    await syncWithServer();
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey);
      if (list != null && list.isNotEmpty) {
        _favoriteIds.addAll(
          list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('FavoritesController._loadFromLocal error: $e');
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _storageKey,
        _favoriteIds.map((e) => e.toString()).toList(),
      );
    } catch (e) {
      debugPrint('FavoritesController._saveToLocal error: $e');
    }
  }

  /// Thả tim / bỏ thả tim cho công thức [recipeId].
  Future<void> toggleFavorite(int recipeId) async {
    if (_favoriteIds.contains(recipeId)) {
      _favoriteIds.remove(recipeId);
    } else {
      _favoriteIds.add(recipeId);
    }
    notifyListeners();
    await _saveToLocal();

    // Đã đăng nhập → đồng bộ backend. API là "toggle mù" nên đối chiếu
    // `isFavorited` trả về với ý định local; lệch thì toggle lại 1 lần.
    if (ApiClient.instance.token != null) {
      final wantFavorited = _favoriteIds.contains(recipeId);
      try {
        final res = await ApiClient.instance.post(
          '/api/Recipes/$recipeId/favorite',
          {},
          timeout: const Duration(seconds: 4),
        );
        if (res is Map && res['isFavorited'] is bool && res['isFavorited'] != wantFavorited) {
          await ApiClient.instance.post(
            '/api/Recipes/$recipeId/favorite',
            {},
            timeout: const Duration(seconds: 4),
          );
        }
      } catch (e) {
        debugPrint('FavoritesController: đồng bộ server lỗi ($e)');
      }
    }
  }

  /// Đồng bộ 2 chiều với server (nếu đã đăng nhập):
  ///   1. Đẩy các id local (thả tim lúc chưa đăng nhập) lên `sync-favorites`.
  ///   2. Kéo danh sách server về làm nguồn chuẩn (server ⊇ local sau bước 1).
  Future<void> syncWithServer() async {
    await _ready;
    if (ApiClient.instance.token == null) return;
    try {
      if (_favoriteIds.isNotEmpty) {
        await ApiClient.instance.post(
          '/api/Recipes/sync-favorites',
          {'recipeIds': _favoriteIds.toList()},
          timeout: const Duration(seconds: 4),
        );
      }
      final data = await ApiClient.instance.get(
        '/api/Recipes/favorites',
        timeout: const Duration(seconds: 4),
      );
      if (data is List) {
        final serverIds = <int>{
          for (final item in data)
            if (item is Map && item['id'] is int) item['id'] as int,
        };
        _favoriteIds
          ..clear()
          ..addAll(serverIds);
        await _saveToLocal();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('FavoritesController.syncWithServer error: $e');
    }
  }

  /// Xoá dữ liệu yêu thích.
  Future<void> clear() async {
    await _ready;
    _favoriteIds.clear();
    await _saveToLocal();
    notifyListeners();
  }
}
