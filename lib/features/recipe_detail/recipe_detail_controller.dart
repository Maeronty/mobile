// =============================================================================
// FEATURE: CHI TIẾT CÔNG THỨC (Recipe Detail + Serving Scaler + Checklist)
// =============================================================================
//
// VAI TRÒ
//   Logic của màn Chi tiết công thức:
//     - Điều chỉnh khẩu phần động (Serving Scaler).
//     - Danh sách nguyên liệu tương tác (tick đã chuẩn bị).
//
// FLOW
//   1. Mở màn chi tiết với `recipeId` → controller lấy công thức từ
//      RecipeRepository, `servings` khởi tạo = khẩu phần gốc của món.
//   2. Bấm [−] / [+] → `decreaseServings()` / `increaseServings()`
//      (tối thiểu 1 phần).
//   3. Mọi định lượng hiển thị = định lượng gốc × `scaleFactor`, với
//          scaleFactor = servings hiện tại / servings gốc
//      VD: món gốc 2 phần, chọn 4 phần → ×2. Áp dụng cho nguyên liệu và các
//      chỉ số dinh dưỡng (đạm, tinh bột, béo, xơ).
//   4. Chạm 1 dòng nguyên liệu → `toggleIngredientCheck(index)` → đánh dấu
//      / bỏ đánh dấu "đã chuẩn bị"; tiêu đề hiển thị `checkedCount / tổng`.
//   5. Bấm "Bắt đầu chế độ nấu ăn" → màn hình mở CookingModeScreen.
//
// LƯU Ý
//   - Món không rõ khẩu phần gốc (servings = 0, VD món Việt cào từ web) →
//     `canScale = false`: giữ nguyên định lượng gốc, không cho bấm [−]/[+].
//   - Nguyên liệu không có định lượng (amount = 0, VD "Muối, tiêu") → không
//     hiện số.
//   - State này là của riêng 1 lần mở màn hình (không singleton) → đóng màn
//     hình là reset khẩu phần & checklist.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/recipe_repository.dart';
import '../../core/models/recipe.dart';

class RecipeDetailController extends ChangeNotifier {
  RecipeDetailController({required int recipeId})
    : recipe = RecipeRepository.instance.findById(recipeId) {
    _servings = recipe.servings;
  }

  /// Công thức đang xem.
  final Recipe recipe;

  late int _servings;
  final Set<int> _checkedIngredients = {};

  /// Số khẩu phần người dùng đang chọn (0 = không rõ khẩu phần gốc).
  int get servings => _servings;

  /// Chỉ nhân định lượng được khi biết khẩu phần gốc.
  bool get canScale => recipe.hasServings;

  /// Hệ số nhân định lượng. Chặn chia cho 0 nếu dữ liệu gốc có servings = 0.
  double get scaleFactor => canScale ? _servings / recipe.servings : 1;

  /// Số nguyên liệu đã được tick "đã chuẩn bị".
  int get checkedCount => _checkedIngredients.length;

  bool isIngredientChecked(int index) => _checkedIngredients.contains(index);

  void increaseServings() {
    if (!canScale) return;
    _servings++;
    notifyListeners();
  }

  /// Giảm khẩu phần, không cho xuống dưới 1.
  void decreaseServings() {
    if (!canScale || _servings <= 1) return;
    _servings--;
    notifyListeners();
  }

  void toggleIngredientCheck(int index) {
    if (!_checkedIngredients.remove(index)) {
      _checkedIngredients.add(index);
    }
    notifyListeners();
  }

  /// Định lượng nguyên liệu sau khi nhân hệ số, định dạng gọn:
  /// số nguyên → "200", số lẻ → "1.5".
  String formatScaledAmount(double baseAmount) {
    if (baseAmount <= 0) return '';
    final scaled = baseAmount * scaleFactor;
    return scaled % 1 == 0
        ? scaled.toInt().toString()
        : scaled.toStringAsFixed(1);
  }

  /// Chỉ số dinh dưỡng (gram) sau khi nhân hệ số, làm tròn số nguyên.
  String formatScaledGrams(double baseGrams) =>
      (baseGrams * scaleFactor).toStringAsFixed(0);
}
