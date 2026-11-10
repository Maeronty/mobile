// =============================================================================
// FEATURE: TRANG CHỦ — KHÁM PHÁ MÓN (danh sách vô hạn có phân trang)
// =============================================================================
//
// VAI TRÒ
//   Toàn bộ dữ liệu + logic của Home: banner nổi bật, danh mục, lưới món tải
//   từng trang khi cuộn. HomeScreen chỉ hiển thị và gọi các hàm ở đây.
//
// FLOW KHỞI TẠO (`init`)
//   1. Cùng lúc gọi: banner (`featured`), danh mục (`categories`), trang 1.
//   2. Server lỗi ở trang 1 → chuyển sang nguồn dự phòng (dữ liệu đóng gói
//      trong app, cùng cách phân trang), `isOffline = true` để UI báo nhẹ.
//
// FLOW CUỘN VÔ HẠN (`loadMore`)
//   1. HomeScreen gọi khi còn < ~1 màn hình nữa là chạm cuối danh sách.
//   2. Bỏ qua nếu đang tải / đã hết / đang lỗi (chờ người dùng bấm thử lại).
//   3. Tải trang kế, nối vào `items`, bỏ món trùng id (phòng dữ liệu đổi giữa
//      các lần gọi).
//
// ĐỔI DANH MỤC (`selectCategory`) / KÉO ĐỂ LÀM MỚI (`refresh`)
//   Xoá danh sách, tăng `_generation` rồi tải lại trang 1. Response của lần gọi
//   cũ về muộn (người dùng bấm chip liên tục) bị bỏ qua nhờ so `_generation`.
//
// HIỆU ỨNG XUẤT HIỆN
//   `shouldAnimate(id)` trả true đúng MỘT lần cho mỗi món → thẻ chỉ trượt vào
//   lần đầu xuất hiện, cuộn lên xuống không nhấp nháy lại.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/api_client.dart';
import '../../core/data/recipe_feed_source.dart';
import '../../core/models/recipe_summary.dart';

class HomeController extends ChangeNotifier {
  static const int pageSize = 20;
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
  final List<RecipeSummary> _items = [];
  final Set<int> _itemIds = {};
  final Set<int> _animated = {};
  int _page = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _isOffline = false;
  String? _error;
  int _generation = 0;
  bool _disposed = false;

  List<RecipeSummary> get featured => _featured;
  List<CategoryCount> get categories => _categories;
  String? get selectedCategory => _selectedCategory;
  List<RecipeSummary> get items => _items;
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get isLoading => _loading;
  bool get isFirstLoad => _loading && _items.isEmpty;
  bool get isOffline => _isOffline;
  String? get error => _error;

  /// Tổng số món của tất cả danh mục (cho chip "Tất cả").
  int get allCount => _categories.fold(0, (sum, c) => sum + c.count);

  /// Tiêu đề phần lưới: "Tất cả món" hoặc tên danh mục đang chọn.
  String get sectionTitle => _selectedCategory ?? 'Tất cả món';

  Future<void> init() async {
    await Future.wait([_loadFirstPage(), _loadMeta()]);
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

  Future<void> _loadFirstPage() async {
    _items.clear();
    _itemIds.clear();
    _page = 0;
    _total = 0;
    _hasMore = true;
    _error = null;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore || _error != null) return;
    final generation = _generation;
    _loading = true;
    _notify();

    try {
      final page = await _fetch(_page + 1);
      if (generation != _generation) return; // đã đổi danh mục trong lúc chờ
      for (final item in page.items) {
        if (_itemIds.add(item.id)) _items.add(item);
      }
      _page = page.page;
      _total = page.total;
      _hasMore = page.hasMore;
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

  /// Lấy 1 trang; trang đầu mà server lỗi → chuyển hẳn sang nguồn dự phòng.
  Future<RecipePage> _fetch(int page) async {
    try {
      return await _source.page(page: page, pageSize: pageSize, category: _selectedCategory);
    } catch (e) {
      if (page != 1 || identical(_source, _fallback)) rethrow;
      debugPrint('HomeController: server lỗi, dùng dữ liệu ngoại tuyến ($e)');
      _source = _fallback;
      _isOffline = true;
      return _source.page(page: page, pageSize: pageSize, category: _selectedCategory);
    }
  }

  /// Bấm "Thử lại" sau lỗi.
  Future<void> retry() {
    _error = null;
    return loadMore();
  }

  Future<void> selectCategory(String? category) async {
    if (category == _selectedCategory) return;
    _selectedCategory = category;
    _generation++;
    _loading = false;
    _notify();
    await _loadFirstPage();
  }

  Future<void> refresh() async {
    _generation++;
    _loading = false;
    _source = _primary; // thử lại server
    _isOffline = false;
    await Future.wait([_loadFirstPage(), _loadMeta()]);
  }

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
