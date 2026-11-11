// =============================================================================
// FEATURE: TRANG CHỦ — KHÁM PHÁ MÓN (xem trước + "Xem tất cả")
// =============================================================================
//
// VAI TRÒ
//   Toàn bộ dữ liệu + logic của Home: banner nổi bật, danh mục, lưới XEM TRƯỚC
//   `previewSize` món của danh mục đang chọn. Danh sách đầy đủ có phân trang
//   nằm ở màn "Xem tất cả" (features/recipe_list). HomeScreen chỉ hiển thị và
//   gọi các hàm ở đây.
//
// FLOW KHỞI TẠO (`init`)
//   1. Cùng lúc gọi: banner (`featured`), danh mục (`categories`), xem trước
//      (trang 1, `previewSize` món — server trả kèm `total`).
//   2. Server lỗi → chuyển sang nguồn dự phòng (dữ liệu đóng gói trong app,
//      cùng cách phân trang), `isOffline = true` để UI báo nhẹ.
//
// ĐỔI DANH MỤC (`selectCategory`) / KÉO ĐỂ LÀM MỚI (`refresh`)
//   Xoá lưới, tăng `_generation` rồi tải lại phần xem trước. Response của lần
//   gọi cũ về muộn (người dùng bấm chip liên tục) bị bỏ qua nhờ so `_generation`.
//
// "XEM TẤT CẢ" (`openAllController`)
//   Hiện khi `hasMoreThanPreview`. Tạo RecipeListController cho danh mục đang
//   chọn, dùng CHUNG nguồn dữ liệu hiện tại (đang ngoại tuyến thì màn kia cũng
//   dùng dữ liệu có sẵn, không chờ server lỗi lần nữa).
//
// HIỆU ỨNG XUẤT HIỆN
//   `shouldAnimate(id)` trả true đúng MỘT lần cho mỗi món → thẻ chỉ trượt vào
//   lần đầu xuất hiện.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/api_client.dart';
import '../../core/data/recipe_feed_source.dart';
import '../../core/models/recipe_summary.dart';
import '../recipe_list/recipe_list_controller.dart';

class HomeController extends ChangeNotifier {
  /// Số món xem trước ở Home (chẵn để lưới 2 cột không hụt ô).
  static const int previewSize = 10;
  static const Duration bannerInterval = Duration(seconds: 5);

  HomeController({RecipeFeedSource? source, RecipeFeedSource? fallback})
      : _primary = source ?? ApiRecipeFeedSource(),
        _fallback = fallback ?? LocalRecipeFeedSource() {
    _source = _primary;
  }

  /// Nguồn chính (server); `_source` có thể tạm chuyển sang `_fallback`.
  final RecipeFeedSource _primary;
  late RecipeFeedSource _source;
  final RecipeFeedSource _fallback;

  List<RecipeSummary> _featured = [];
  List<CategoryCount> _categories = [];
  String? _selectedCategory;
  List<RecipeSummary> _items = [];
  final Set<int> _animated = {};
  int _total = 0;
  bool _loading = false;
  bool _isOffline = false;
  String? _error;
  int _generation = 0;
  bool _disposed = false;

  List<RecipeSummary> get featured => _featured;
  List<CategoryCount> get categories => _categories;
  String? get selectedCategory => _selectedCategory;

  /// Các món xem trước (tối đa `previewSize`).
  List<RecipeSummary> get items => _items;

  /// Tổng số món của danh mục đang chọn (từ server).
  int get total => _total;
  bool get isLoading => _loading;
  bool get isOffline => _isOffline;
  String? get error => _error;

  /// Còn món ngoài phần xem trước → hiện nút "Xem tất cả".
  bool get hasMoreThanPreview => _total > _items.length;

  /// Tổng số món của tất cả danh mục (cho chip "Tất cả").
  int get allCount => _categories.fold(0, (sum, c) => sum + c.count);

  /// Tiêu đề phần lưới: "Tất cả món" hoặc tên danh mục đang chọn.
  String get sectionTitle => _selectedCategory ?? 'Tất cả món';

  Future<void> init() async {
    await Future.wait([_loadPreview(), _loadMeta()]);
  }

  Future<void> _loadMeta() async {
    try {
      final results = await Future.wait([_source.featured(), _source.categories()]);
      _featured = results[0] as List<RecipeSummary>;
      _categories = results[1] as List<CategoryCount>;
    } catch (_) {
      try {
        final results = await Future.wait([_fallback.featured(), _fallback.categories()]);
        _featured = results[0] as List<RecipeSummary>;
        _categories = results[1] as List<CategoryCount>;
      } catch (e) {
        debugPrint('HomeController: không tải được banner/danh mục: $e');
      }
    }
    _notify();
  }

  Future<void> _loadPreview() async {
    final generation = _generation;
    _items = [];
    _total = 0;
    _error = null;
    _loading = true;
    _notify();

    try {
      final page = await _fetchPreview();
      if (generation != _generation) return; // đã đổi danh mục trong lúc chờ
      _items = page.items;
      _total = page.total;
    } catch (e) {
      if (generation != _generation) return;
      _error = e is ApiException ? e.message : 'Không tải được danh sách món.';
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Lấy phần xem trước; server lỗi → chuyển hẳn sang nguồn dự phòng.
  Future<RecipePage> _fetchPreview() async {
    try {
      return await _source.page(page: 1, pageSize: previewSize, category: _selectedCategory);
    } catch (e) {
      if (identical(_source, _fallback)) rethrow;
      debugPrint('HomeController: server lỗi, dùng dữ liệu ngoại tuyến ($e)');
      _source = _fallback;
      _isOffline = true;
      return _source.page(page: 1, pageSize: previewSize, category: _selectedCategory);
    }
  }

  /// Bấm "Thử lại" sau lỗi.
  Future<void> retry() {
    _generation++;
    return _loadPreview();
  }

  Future<void> selectCategory(String? category) async {
    if (category == _selectedCategory) return;
    _selectedCategory = category;
    _generation++;
    await _loadPreview();
  }

  Future<void> refresh() async {
    _generation++;
    _source = _primary; // thử lại server
    _isOffline = false;
    await Future.wait([_loadPreview(), _loadMeta()]);
  }

  /// Controller cho màn "Xem tất cả" của danh mục đang chọn.
  RecipeListController openAllController() => RecipeListController(
        source: _source,
        fallback: _fallback,
        category: _selectedCategory,
      );

  bool shouldAnimate(int id) => _animated.add(id);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
