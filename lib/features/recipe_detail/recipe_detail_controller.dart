// =============================================================================
// FEATURE: CHI TIẾT CÔNG THỨC (tải theo id + Checklist nguyên liệu)
// =============================================================================
//
// VAI TRÒ
//   Logic của màn Chi tiết công thức:
//     - Tải công thức đầy đủ theo id (không cần tải cả danh mục trước).
//     - Danh sách nguyên liệu tương tác (tick đã chuẩn bị).
//   (Không còn chỉnh khẩu phần: định lượng hiển thị đúng như công thức gốc.)
//
// FLOW TẢI (`load`, gọi ngay khi tạo controller)
//   1. `GET /api/Recipes/:id` → Recipe.fromDetailJson.
//   2. Lỗi (server tắt / mất mạng) → tìm trong RecipeRepository (danh mục đóng
//      gói sẵn) để vẫn xem được offline.
//   3. Vẫn không có → `error` + nút "Thử lại" (gọi lại `load`).
//   Trong lúc tải, màn hình đã hiện sẵn ảnh + tên món từ thẻ vừa bấm (preview)
//   và khung chờ cho phần còn lại.
//
// FLOW CHECKLIST
//   Chạm 1 dòng nguyên liệu → `toggleIngredientCheck(index)`.
//
// LƯU Ý
//   - Nguyên liệu không có định lượng (amount = 0, VD "Muối, tiêu") → không
//     hiện số.
//   - State này là của riêng 1 lần mở màn hình (không singleton).
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/api_client.dart';
import '../../core/data/recipe_repository.dart';
import '../../core/models/recipe.dart';

class RecipeDetailController extends ChangeNotifier {
  RecipeDetailController({required this.recipeId, ApiClient? api}) : _api = api ?? ApiClient.instance {
    load();
  }

  final int recipeId;
  final ApiClient _api;

  Recipe? _recipe;
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  final Set<int> _checkedIngredients = {};

  /// Công thức đầy đủ; null khi đang tải hoặc lỗi.
  Recipe? get recipe => _recipe;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _notify();

    Recipe? result;
    try {
      final data = await _api.get('/api/Recipes/$recipeId', timeout: const Duration(seconds: 10));
      result = Recipe.fromDetailJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('RecipeDetailController: server lỗi ($e), thử dữ liệu có sẵn');
      final repo = RecipeRepository.instance;
      if (repo.isLoaded) {
        result = repo.all.where((r) => r.id == recipeId).firstOrNull;
      }
      if (result == null) {
        _error = e is ApiException ? e.message : 'Không tải được công thức.';
      }
    }

    if (result != null) _recipe = result;
    _loading = false;
    _notify();
  }

  /// Số nguyên liệu đã được tick "đã chuẩn bị".
  int get checkedCount => _checkedIngredients.length;

  bool isIngredientChecked(int index) => _checkedIngredients.contains(index);

  void toggleIngredientCheck(int index) {
    if (!_checkedIngredients.remove(index)) {
      _checkedIngredients.add(index);
    }
    _notify();
  }

  /// Định lượng nguyên liệu, định dạng gọn: số nguyên → "200", số lẻ → "1.5";
  /// không có định lượng (0) → "".
  String formatAmount(double amount) {
    if (amount <= 0) return '';
    return amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(1);
  }

  /// Chỉ số dinh dưỡng (gram), làm tròn số nguyên.
  String formatGrams(double grams) => grams.toStringAsFixed(0);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
