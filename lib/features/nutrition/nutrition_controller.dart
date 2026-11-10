// =============================================================================
// FEATURE: CỐ VẤN DINH DƯỠNG & LẬP THỰC ĐƠN 7 NGÀY (Nutrition Advisor)
// =============================================================================
//
// VAI TRÒ
//   Lưu lựa chọn của người dùng (đối tượng, mục tiêu sức khoẻ, ngày đang xem)
//   và tạo thực đơn tương ứng.
//
// FLOW
//   1. Khởi tạo → mặc định "Gia đình (4 người)" + "Cân bằng", tạo ngay thực đơn
//      đầu tiên (không loading).
//   2. Người dùng chọn chip đối tượng / mục tiêu → `selectTargetGroup` /
//      `selectHealthGoal` (CHƯA tạo lại thực đơn, chờ bấm nút).
//   3. Bấm "Tạo lại thực đơn thông minh" → `generatePlan()`:
//        a. isLoading = true → nút hiện vòng xoay & bị khoá.
//        b. Chờ 600ms (mô phỏng gọi AI / server).
//        c. Tạo thực đơn mới theo lựa chọn, quay về ngày đầu tiên,
//           isLoading = false.
//        d. Trả về `true` để UI hiện SnackBar thành công.
//   4. Chạm chip ngày → `selectDay(index)` → `activeDayPlan` đổi theo.
//
// NGUỒN DỮ LIỆU
//   Thực đơn lấy từ danh mục Spoonacular trong RecipeRepository.
//   Khi có API thật chỉ cần thay `_buildPlan()`.
//
// LƯU Ý
//   - NutritionAdvisorScreen hiện CHƯA được gắn vào thanh điều hướng.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/recipe_repository.dart';
import '../../core/models/meal_plan.dart';

/// Một lựa chọn hiển thị dạng chip (đối tượng hoặc mục tiêu).
class NutritionOption {
  /// Giá trị lưu & truyền vào bộ tạo thực đơn.
  final String id;

  /// Nhãn chính hiển thị.
  final String label;

  /// Nhãn phụ (số người / mô tả ngắn).
  final String sub;

  const NutritionOption(this.id, this.label, this.sub);
}

class NutritionController extends ChangeNotifier {
  /// Thời gian mô phỏng chờ AI tạo thực đơn.
  static const Duration fakeGenerateDelay = Duration(milliseconds: 600);

  static const List<NutritionOption> targetGroups = [
    NutritionOption('Cá nhân', 'Cá nhân', '1 người'),
    NutritionOption('Cặp đôi', 'Cặp đôi', '2 người'),
    NutritionOption('Gia đình (4 người)', 'Gia đình', '4 người'),
    NutritionOption('Đại gia đình', 'Đại gia đình', '6+ người'),
  ];

  static const List<NutritionOption> healthGoals = [
    NutritionOption('Cân bằng', 'Cân bằng', 'Tiết kiệm & Đủ chất'),
    NutritionOption('Giảm cân', 'Giảm mỡ', 'Kiểm soát calo'),
    NutritionOption('Tăng cơ', 'Tăng cơ', 'Giàu protein'),
    NutritionOption('Eat Clean', 'Eat Clean', 'Thanh lọc cơ thể'),
  ];

  NutritionController() {
    _currentPlan = _buildPlan();
  }

  String _selectedTargetGroup = 'Gia đình (4 người)';
  String _selectedHealthGoal = 'Cân bằng';
  int _selectedDayIndex = 0;
  bool _isLoading = false;
  bool _disposed = false;
  late MealPlan _currentPlan;

  String get selectedTargetGroup => _selectedTargetGroup;
  String get selectedHealthGoal => _selectedHealthGoal;
  int get selectedDayIndex => _selectedDayIndex;
  bool get isLoading => _isLoading;
  MealPlan get currentPlan => _currentPlan;
  List<DailyPlan> get dailyPlans => _currentPlan.dailyPlans;

  /// Kế hoạch của ngày đang chọn (dùng modulo để không vượt quá số ngày).
  DailyPlan get activeDayPlan => dailyPlans[_selectedDayIndex % dailyPlans.length];

  void selectTargetGroup(String id) {
    _selectedTargetGroup = id;
    notifyListeners();
  }

  void selectHealthGoal(String id) {
    _selectedHealthGoal = id;
    notifyListeners();
  }

  void selectDay(int index) {
    _selectedDayIndex = index;
    notifyListeners();
  }

  /// Tạo lại thực đơn theo lựa chọn hiện tại.
  /// Trả về `false` nếu màn hình đã đóng trong lúc chờ (không cần báo UI).
  Future<bool> generatePlan() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(fakeGenerateDelay);
    if (_disposed) return false;

    _currentPlan = _buildPlan();
    _selectedDayIndex = 0;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  MealPlan _buildPlan() {
    final recipes = [...RecipeRepository.instance.all];
    if (_selectedHealthGoal == 'Giảm cân') {
      recipes.sort((a, b) => a.calories.compareTo(b.calories));
    } else if (_selectedHealthGoal == 'Tăng cơ') {
      recipes.sort((a, b) => b.nutrition.proteinGrams.compareTo(a.nutrition.proteinGrams));
    }
    const weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật'];
    final days = List.generate(7, (day) {
      final meals = List.generate(3, (index) {
        final r = recipes[(day * 3 + index) % recipes.length];
        return MealItem(mealType: ['Bữa sáng', 'Bữa trưa', 'Bữa tối'][index], dishName: r.title,
            imageAsset: r.imageAsset, calories: r.calories, proteinGrams: r.nutrition.proteinGrams,
            carbsGrams: r.nutrition.carbsGrams, fatGrams: r.nutrition.fatGrams, tip: r.description);
      });
      return DailyPlan(dayNumber: day + 1, dayName: weekdays[day], meals: meals,
          totalCalories: meals.fold<int>(0, (sum, m) => sum + m.calories),
          nutritionSummary: 'Dinh dưỡng ước tính cho một khẩu phần mỗi món.');
    });
    return MealPlan(targetGroup: _selectedTargetGroup, healthGoal: _selectedHealthGoal,
        totalDays: days.length, dailyPlans: days, advisorAdvice: 'Thực đơn tham khảo từ Spoonacular.');
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
