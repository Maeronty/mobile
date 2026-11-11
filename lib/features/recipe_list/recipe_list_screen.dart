// =============================================================================
// MÀN HÌNH: XEM TẤT CẢ MÓN (mở từ nút "Xem tất cả" ở Home)
// =============================================================================
//
// FILE NÀY CHỈ GHÉP GIAO DIỆN; dữ liệu + phân trang nằm trong
// `recipe_list_controller.dart`. Lưới và chân lưới dùng lại widget của Home.
//
// BỐ CỤC (một CustomScrollView duy nhất → cuộn mượt, dựng lười)
//   1. App bar ghim: tên danh mục (hoặc "Tất cả món") + tổng số món.
//   2. Báo nhẹ nếu đang dùng dữ liệu ngoại tuyến.
//   3. Lưới món, mỗi lần tải 1 trang (20 món).
//   4. Chân lưới: khung chờ / lỗi + "Thử lại" / "Bạn đã xem hết N món".
//
// FLOW UI
//   - Mở màn → controller.init(): trang 1 (khung chờ shimmer).
//   - Cuộn tới khi còn < 900 px là chạm cuối → controller.loadMore().
//   - Màn cao (tablet) chưa đủ món để cuộn → tự tải tiếp tới khi đầy màn.
//   - Kéo xuống ở đầu trang → làm mới (thử lại server nếu đang ngoại tuyến).
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../home/widgets/home_recipe_grid.dart';
import 'recipe_list_controller.dart';

class RecipeListScreen extends StatefulWidget {
  /// Danh mục cần xem; null = tất cả món. Bỏ qua nếu truyền `controller`.
  final String? category;

  /// Cho Home truyền controller dùng chung nguồn dữ liệu, và cho test.
  /// Màn này GIỮ QUYỀN SỞ HỮU: tự dispose controller khi đóng.
  final RecipeListController? controller;

  const RecipeListScreen({super.key, this.category, this.controller});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  late final RecipeListController _controller =
      widget.controller ?? RecipeListController(category: widget.category);
  final ScrollController _scroll = ScrollController();

  static const double _loadMoreThreshold = 900;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _scroll.addListener(_maybeLoadMore);
    _controller.init().then((_) => _fillViewport());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < _loadMoreThreshold) {
      _controller.loadMore();
    }
  }

  /// Màn hình cao có thể chưa đủ món để cuộn → tải thêm.
  void _fillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent < _loadMoreThreshold && _controller.hasMore && _controller.error == null) {
        _controller.loadMore().then((_) => _fillViewport());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await c.refresh();
          _fillViewport();
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          cacheExtent: 600,
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (c.total > 0)
                    Text('${formatCount(c.total)} món', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (c.isOffline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Không kết nối được máy chủ — đang dùng dữ liệu có sẵn. Kéo xuống để thử lại.',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            HomeRecipeGrid(items: c.items, shouldAnimate: c.shouldAnimate, pageSize: c.pageSize),
            HomeGridFooter(
              loading: c.isLoading,
              hasMore: c.hasMore,
              error: c.error,
              total: c.total,
              fillViewport: c.items.isEmpty,
              onRetry: () => c.retry().then((_) => _fillViewport()),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1829 → "1.829" (dấu chấm phân cách hàng nghìn kiểu Việt Nam).
String formatCount(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}
