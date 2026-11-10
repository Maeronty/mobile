// =============================================================================
// FEATURE: SURPRISE ME — HÔM NAY ĂN GÌ? (Random Recipe Picker)
// =============================================================================
//
// VAI TRÒ
//   Quản lý bộ lọc tùy biến, logic chọn món ngẫu nhiên và tiến trình hoạt ảnh
//   đầu bếp nấu ăn trong 4 giây.
//
// FLOW
//   1. Người dùng tùy chỉnh bộ lọc (Thể loại, Thời gian, Độ khó).
//      Nếu không toggle filter nào → mặc định random 100% kho công thức.
//   2. Nhấn 'Đầu bếp bí mật, nấu ngay!' → `startCooking()`:
//        - State chuyển sang `SurpriseState.cooking`.
//        - Đếm ngược 4s với thông điệp vui nhộn.
//   3. Hết 4s → Random 1 món từ danh sách thỏa mãn → State: `SurpriseState.result`.
//   4. Tại màn kết quả: người dùng có thể Xem công thức, Nấu ngay, Thả tim,
//      hoặc bấm 'Đổi món khác' (reroll) để đầu bếp nấu lại.
// =============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../../core/data/recipe_repository.dart';
import '../../core/models/recipe.dart';

enum SurpriseState {
  setup,
  cooking,
  result,
}

class SurpriseMeController extends ChangeNotifier {
  static List<String> get availableCategories => RecipeRepository.instance.categories;

  static const List<String> availableDifficulties = [
    'Dễ',
    'Trung bình',
    'Khó',
  ];

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------
  SurpriseState _state = SurpriseState.setup;
  final Set<String> _selectedCategories = {};
  int? _selectedTimeFilter; // 1: <=20p, 2: 21-40p, 3: >40p
  String? _selectedDifficulty;

  Recipe? _currentRecipe;
  int _countdownSeconds = 4;
  String _cookingMessage = 'Đang chọn nguyên liệu tươi ngon nhất...';
  Timer? _countdownTimer;

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------
  SurpriseState get state => _state;
  Set<String> get selectedCategories => Set.unmodifiable(_selectedCategories);
  int? get selectedTimeFilter => _selectedTimeFilter;
  String? get selectedDifficulty => _selectedDifficulty;
  Recipe? get currentRecipe => _currentRecipe;
  int get countdownSeconds => _countdownSeconds;
  String get cookingMessage => _cookingMessage;

  bool get hasActiveFilter =>
      _selectedCategories.isNotEmpty ||
      _selectedTimeFilter != null ||
      _selectedDifficulty != null;

  /// Lọc danh sách công thức theo bộ lọc hiện tại.
  /// Nếu không có bộ lọc nào được chọn → trả về toàn bộ kho công thức.
  List<Recipe> get matchingRecipes {
    final all = RecipeRepository.instance.all;
    if (!hasActiveFilter) return all;

    return all.where((r) {
      // 1. Thể loại
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(r.category)) {
        return false;
      }

      // 2. Thời gian nấu
      if (_selectedTimeFilter != null) {
        // Món không rõ thời gian nấu không thuộc khoảng nào.
        if (!r.hasCookTime) return false;
        if (_selectedTimeFilter == 1 && r.cookTimeMinutes > 20) return false;
        if (_selectedTimeFilter == 2 &&
            (r.cookTimeMinutes <= 20 || r.cookTimeMinutes > 40)) {
          return false;
        }
        if (_selectedTimeFilter == 3 && r.cookTimeMinutes <= 40) return false;
      }

      // 3. Độ khó
      if (_selectedDifficulty != null &&
          r.difficulty.toLowerCase() != _selectedDifficulty!.toLowerCase()) {
        return false;
      }

      return true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // BỘ LỌC ACTIONS
  // ---------------------------------------------------------------------------
  void toggleCategory(String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    notifyListeners();
  }

  void setTimeFilter(int? filter) {
    _selectedTimeFilter = (_selectedTimeFilter == filter) ? null : filter;
    notifyListeners();
  }

  void setDifficulty(String? difficulty) {
    _selectedDifficulty =
        (_selectedDifficulty == difficulty) ? null : difficulty;
    notifyListeners();
  }

  void clearAllFilters() {
    _selectedCategories.clear();
    _selectedTimeFilter = null;
    _selectedDifficulty = null;
    notifyListeners();
  }

  void backToSetup() {
    _countdownTimer?.cancel();
    _state = SurpriseState.setup;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // NẤU ĂN & RANDOM
  // ---------------------------------------------------------------------------
  void startCooking() {
    final matches = matchingRecipes;
    if (matches.isEmpty) return;

    _countdownTimer?.cancel();
    _state = SurpriseState.cooking;
    _countdownSeconds = 4;
    _updateCookingMessage(4);
    notifyListeners();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownSeconds--;
      if (_countdownSeconds > 0) {
        _updateCookingMessage(_countdownSeconds);
        notifyListeners();
      } else {
        timer.cancel();
        _pickRandomRecipe(matches);
        _state = SurpriseState.result;
        notifyListeners();
      }
    });
  }

  void reroll() {
    startCooking();
  }

  void _updateCookingMessage(int second) {
    switch (second) {
      case 4:
        _cookingMessage = 'Đang chọn những nguyên liệu tươi ngon nhất...';
        break;
      case 3:
        _cookingMessage = 'Lửa bùng lên, đầu bếp đảo chảo đều tay...';
        break;
      case 2:
        _cookingMessage = 'Hương vị thơm lừng bốc lên ngây ngất...';
        break;
      case 1:
        _cookingMessage = 'Chuẩn bị dọn món ngon nóng hổi ra bàn ăn!';
        break;
      default:
        _cookingMessage = 'Món ngon bí mật đã sẵn sàng!';
    }
  }

  void _pickRandomRecipe(List<Recipe> pool) {
    final rand = Random();
    if (pool.length == 1) {
      _currentRecipe = pool.first;
      return;
    }

    // Nếu có nhiều món, ưu tiên chọn món khác món hiện tại để tạo cảm giác đổi mới
    List<Recipe> candidates = pool;
    if (_currentRecipe != null) {
      candidates = pool.where((r) => r.id != _currentRecipe!.id).toList();
      if (candidates.isEmpty) candidates = pool;
    }

    _currentRecipe = candidates[rand.nextInt(candidates.length)];
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
