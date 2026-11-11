// =============================================================================
// FEATURE: DANH SÁCH MÓN ĐẦY ĐỦ ("Xem tất cả" từ Home) — cuộn có phân trang
// =============================================================================
//
// VAI TRÒ
//   Dữ liệu + logic phân trang của màn "Xem tất cả". RecipeListScreen chỉ hiển
//   thị và gọi các hàm ở đây. Danh mục cố định theo lúc mở từ Home
//   (`category == null` → tất cả món).
//
// FLOW KHỞI TẠO (`init`)
//   1. Tải trang 1 (`pageSize` món).
//   2. Server lỗi ở trang 1 → chuyển sang nguồn dự phòng (dữ liệu đóng gói
//      trong app, cùng cách phân trang), `isOffline = true` để UI báo nhẹ.
//
// FLOW TẢI TRANG KẾ (`loadMore`)
//   1. Màn hình gọi khi còn < ~1 màn hình nữa là chạm cuối danh sách.
//   2. Bỏ qua nếu đang tải / đã hết / đang lỗi (chờ người dùng bấm thử lại).
//   3. Tải trang kế, nối vào `items`, bỏ món trùng id (phòng dữ liệu đổi giữa
//      các lần gọi).
//
// KÉO ĐỂ LÀM MỚI (`refresh`)
//   Xoá danh sách, tăng `_generation`, thử lại server rồi tải lại trang 1.
//   Response của lần gọi cũ về muộn bị bỏ qua nhờ so `_generation`.
//
// HIỆU ỨNG XUẤT HIỆN
//   `shouldAnimate(id)` trả true đúng MỘT lần cho mỗi món → thẻ chỉ trượt vào
//   lần đầu xuất hiện, cuộn lên xuống không nhấp nháy lại.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/api_client.dart';
import '../../core/data/recipe_feed_source.dart';
import '../../core/models/recipe_summary.dart';

class RecipeListController extends ChangeNotifier {
  static const int defaultPageSize = 20;

  RecipeListController({
    RecipeFeedSource? source,
    RecipeFeedSource? fallback,
    this.category,
    this.pageSize = defaultPageSize,
  })  : _primary = source ?? ApiRecipeFeedSource(),
        _fallback = fallback ?? LocalRecipeFeedSource() {
    _source = _primary;
  }

  /// Danh mục đang xem; null = tất cả món.
  final String? category;
  final int pageSize;

  /// Nguồn chính (server); `_source` có thể tạm chuyển sang `_fallback`.
  final RecipeFeedSource _primary;
  late RecipeFeedSource _source;
  final RecipeFeedSource _fallback;

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

  List<RecipeSummary> get items => _items;
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get isLoading => _loading;
  bool get isOffline => _isOffline;
  String? get error => _error;

  /// Tiêu đề màn: "Tất cả món" hoặc tên danh mục.
  String get title => category ?? 'Tất cả món';

  Future<void> init() => _loadFirstPage();

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
      if (generation != _generation) return; // đã làm mới trong lúc chờ
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
      return await _source.page(page: page, pageSize: pageSize, category: category);
    } catch (e) {
      if (page != 1 || identical(_source, _fallback)) rethrow;
      debugPrint('RecipeListController: server lỗi, dùng dữ liệu ngoại tuyến ($e)');
      _source = _fallback;
      _isOffline = true;
      return _source.page(page: page, pageSize: pageSize, category: category);
    }
  }

  /// Bấm "Thử lại" sau lỗi.
  Future<void> retry() {
    _error = null;
    return loadMore();
  }

  Future<void> refresh() async {
    _generation++;
    _loading = false;
    _source = _primary; // thử lại server
    _isOffline = false;
    await _loadFirstPage();
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
