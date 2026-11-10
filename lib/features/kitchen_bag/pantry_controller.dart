// =============================================================================
// FEATURE: TỦ LẠNH / KHO NGUYÊN LIỆU (Pantry — tab đầu của "Túi Thần Kỳ")
// =============================================================================
//
// VAI TRÒ
//   Lưu danh sách nguyên liệu người dùng đang có trong tủ lạnh. Danh sách này
//   là đầu vào cho thuật toán gợi ý món (xem features/suggest/suggest_controller.dart).
//
// FLOW
//   1. Khởi tạo tủ trống. Người dùng chọn nguyên liệu Spoonacular hoặc nhập tay.
//   2. Thêm: người dùng gõ tên → bấm "Thêm"/Enter → `addIngredient(text)`:
//        a. Cắt khoảng trắng đầu/cuối (`trim`).
//        b. Bỏ qua nếu rỗng hoặc đã tồn tại (tránh trùng lặp).
//        c. Thêm vào cuối danh sách → `notifyListeners()`.
//   3. Xoá 1 món: bấm dấu × trên chip → `removeIngredient(name)`.
//   4. Dọn sạch: bấm "Dọn sạch tủ" → `clear()`.
//   5. Bấm "Gợi ý món từ N nguyên liệu này" → KitchenBagScreen mở SuggestScreen
//      với `initialIngredients = ingredients`.
//
// LƯU Ý
//   - So sánh trùng là phân biệt hoa/thường ("thịt bò" ≠ "Thịt bò"), giữ nguyên
//     hành vi cũ.
// =============================================================================

import 'package:flutter/foundation.dart';

class PantryController extends ChangeNotifier {
  /// Singleton: tủ lạnh dùng chung cho Túi Thần Kỳ và màn Gợi ý.
  static final PantryController instance = PantryController._();

  PantryController._();

  final List<String> _ingredients = [];

  /// Danh sách nguyên liệu hiện có (chỉ đọc).
  List<String> get ingredients => List.unmodifiable(_ingredients);

  /// Thêm nguyên liệu mới. Trả về `true` nếu thêm thành công.
  bool addIngredient(String ingredient) {
    final clean = ingredient.trim();
    if (clean.isEmpty || _ingredients.contains(clean)) return false;

    _ingredients.add(clean);
    notifyListeners();
    return true;
  }

  /// Xoá một nguyên liệu khỏi tủ.
  void removeIngredient(String ingredient) {
    _ingredients.remove(ingredient);
    notifyListeners();
  }

  /// Dọn sạch toàn bộ tủ lạnh.
  void clear() {
    _ingredients.clear();
    notifyListeners();
  }
}
