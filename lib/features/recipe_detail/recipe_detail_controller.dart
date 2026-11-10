// =============================================================================
// FEATURE: CHI TIẾT CÔNG THỨC (tải theo id + Serving Scaler + Checklist)
// =============================================================================
//
// VAI TRÒ
//   Logic của màn Chi tiết công thức:
//     - Tải công thức đầy đủ theo id (không cần tải cả danh mục trước).
//     - Điều chỉnh khẩu phần động (Serving Scaler).
//     - Danh sách nguyên liệu tương tác (tick đã chuẩn bị).
//
// FLOW TẢI (`load`, gọi ngay khi tạo controller)
//   1. `GET /api/Recipes/:id` → Recipe.fromDetailJson.
//   2. Lỗi (server tắt / mất mạng) → tìm trong RecipeRepository (danh mục đóng
//      gói sẵn) để vẫn xem được offline.
//   3. Vẫn không có → `error` + nút "Thử lại" (gọi lại `load`).
//   Trong lúc tải, màn hình đã hiện sẵn ảnh + tên món từ thẻ vừa bấm (preview)
//   và khung chờ cho phần còn lại.
//
// FLOW KHẨU PHẦN
//   1. Có công thức → `servings` = khẩu phần gốc của món.
//   2. Bấm [−] / [+] → `decreaseServings()` / `increaseServings()` (tối thiểu 1).
//   3. Định lượng hiển thị = định lượng gốc × `scaleFactor`
//      (= servings hiện tại / servings gốc), áp dụng cho nguyên liệu và dinh dưỡng.
//   4. Chạm 1 dòng nguyên liệu → `toggleIngredientCheck(index)`.
//
// LƯU Ý
//   - Món không rõ khẩu phần gốc (servings = 0, VD món Việt cào từ web) →
//     `canScale = false`: giữ nguyên định lượng gốc, không cho bấm [−]/[+].
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

  int _servings = 0;
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

    if (result != null) {
      _recipe = result;
      _servings = result.servings;
    }
    _loading = false;
    _notify();
  }

  /// Số khẩu phần người dùng đang chọn (0 = không rõ khẩu phần gốc).
  int get servings => _servings;

  /// Chỉ nhân định lượng được khi biết khẩu phần gốc.
  bool get canScale => _recipe?.hasServings ?? false;

  /// Hệ số nhân định lượng.
  double get scaleFactor => canScale ? _servings / _recipe!.servings : 1;

  /// Số nguyên liệu đã được tick "đã chuẩn bị".
  int get checkedCount => _checkedIngredients.length;

  bool isIngredientChecked(int index) => _checkedIngredients.contains(index);

  void increaseServings() {
    if (!canScale) return;
    _servings++;
    _notify();
  }

  /// Giảm khẩu phần, không cho xuống dưới 1.
  void decreaseServings() {
    if (!canScale || _servings <= 1) return;
    _servings--;
    _notify();
  }

  void toggleIngredientCheck(int index) {
    if (!_checkedIngredients.remove(index)) {
      _checkedIngredients.add(index);
    }
    _notify();
  }

  /// Định lượng nguyên liệu sau khi nhân hệ số, định dạng gọn:
  /// số nguyên → "200", số lẻ → "1.5".
  String formatScaledAmount(double baseAmount) {
    if (baseAmount <= 0) return '';
    final scaled = baseAmount * scaleFactor;
    return scaled % 1 == 0 ? scaled.toInt().toString() : scaled.toStringAsFixed(1);
  }

  /// Chỉ số dinh dưỡng (gram) sau khi nhân hệ số, làm tròn số nguyên.
  String formatScaledGrams(double baseGrams) => (baseGrams * scaleFactor).toStringAsFixed(0);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
