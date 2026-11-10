// =============================================================================
// FEATURE: TRANG CHỦ — KHÁM PHÁ CÔNG THỨC (Explore & Home)
// =============================================================================
//
// VAI TRÒ
//   Chứa dữ liệu hiển thị và logic lọc của Trang chủ:
//     - Banner Coverflow tự động trượt.
//     - Lọc công thức theo danh mục.
//     - Bộ sưu tập "Nấu nhanh" (≤ 25 phút).
//
// FLOW
//   1. HomeScreen tạo HomeController trong initState và lắng nghe thay đổi.
//   2. BANNER: HomeScreen chạy Timer mỗi `bannerInterval` (4s):
//        - Hỏi controller `nextBannerIndex` = (index hiện tại + 1) % số banner
//          → quay vòng về banner đầu sau banner cuối.
//        - PageView trượt tới trang đó → `onPageChanged` → `setBannerIndex(idx)`
//          → cập nhật chấm chỉ báo bên dưới banner.
//   3. DANH MỤC: chạm chip → `selectCategory(cat)`:
//        - "Tất cả"        → `filteredRecipes` trả về toàn bộ công thức.
//        - Danh mục khác   → chỉ giữ công thức có `category` trùng khớp.
//   4. NẤU NHANH: `fastRecipes` lọc công thức có `cookTimeMinutes ≤ 25`.
//
// LƯU Ý
//   - Timer & PageController là đối tượng UI nên vẫn nằm trong HomeScreen,
//     controller chỉ quyết định "trang tiếp theo là trang nào".
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/recipe_repository.dart';
import '../../core/models/recipe.dart';

class HomeController extends ChangeNotifier {
  /// Danh mục đặc biệt: hiển thị toàn bộ công thức.
  static const String allCategory = 'Tất cả';

  /// Ngưỡng thời gian (phút) để một món được xem là "nấu nhanh".
  static const int fastCookMaxMinutes = 25;

  /// Khoảng thời gian giữa 2 lần banner tự trượt.
  static const Duration bannerInterval = Duration(seconds: 4);

  /// Dữ liệu banner nổi bật đầu trang.
  static List<Map<String, String>> get heroBanners => RecipeRepository.instance.all.take(4).map((r) => {
    'title': r.title, 'subtitle': r.description, 'image': r.imageAsset, 'tag': r.category,
  }).toList();

  /// Danh sách chip danh mục.
  static List<String> get categories => [allCategory, ...RecipeRepository.instance.categories];

  String _selectedCategory = allCategory;
  int _currentBannerIndex = 0;

  String get selectedCategory => _selectedCategory;
  int get currentBannerIndex => _currentBannerIndex;
  bool get isAllCategory => _selectedCategory == allCategory;

  // ---------------------------------------------------------------------------
  // BANNER
  // ---------------------------------------------------------------------------

  /// Trang banner kế tiếp (quay vòng về 0 sau trang cuối).
  int get nextBannerIndex => (_currentBannerIndex + 1) % heroBanners.length;

  /// Gọi khi PageView đổi trang (do người dùng vuốt hoặc timer tự trượt).
  void setBannerIndex(int index) {
    _currentBannerIndex = index;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // DANH MỤC & BỘ SƯU TẬP
  // ---------------------------------------------------------------------------

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Công thức thuộc danh mục đang chọn.
  List<Recipe> get filteredRecipes {
    final all = RecipeRepository.instance.all;
    if (isAllCategory) return all;
    return all.where((r) => r.category == _selectedCategory).toList();
  }

  /// Công thức nấu nhanh (≤ [fastCookMaxMinutes] phút).
  List<Recipe> get fastRecipes {
    return RecipeRepository.instance.all
        .where((r) => r.cookTimeMinutes <= fastCookMaxMinutes)
        .toList();
  }
}
