// Test Home (xem trước + "Xem tất cả") và màn danh sách đầy đủ có phân trang,
// dùng nguồn dữ liệu giả; màn thật không lỗi layout, không còn timer treo.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/core/data/recipe_feed_source.dart';
import 'package:tomato_food_tip/core/models/recipe_summary.dart';
import 'package:tomato_food_tip/core/widgets/recipe_tile_card.dart';
import 'package:tomato_food_tip/features/home/home_controller.dart';
import 'package:tomato_food_tip/features/home/home_screen.dart';
import 'package:tomato_food_tip/features/recipe_list/recipe_list_controller.dart';
import 'package:tomato_food_tip/features/recipe_list/recipe_list_screen.dart';

RecipeSummary dish(int id, String category) => RecipeSummary(
      id: id,
      title: 'Món $id',
      image: '',
      category: category,
      source: 'Test',
      cookTimeMinutes: 0,
      calories: 0,
      ingredientCount: 5,
    );

class FakeSource implements RecipeFeedSource {
  FakeSource(this.all, {this.failPage, this.failAlways = false});

  final List<RecipeSummary> all;
  int? failPage;
  bool failAlways;
  final requests = <String>[];
  Completer<void>? gate;

  @override
  Future<RecipePage> page({required int page, required int pageSize, String? category}) async {
    requests.add('$category#$page');
    if (gate != null) await gate!.future;
    if (failAlways || page == failPage) throw Exception('server lỗi');
    final list = category == null ? all : all.where((r) => r.category == category).toList();
    final items = list.skip((page - 1) * pageSize).take(pageSize).toList();
    return RecipePage(items: items, page: page, total: list.length, hasMore: page * pageSize < list.length);
  }

  @override
  Future<List<CategoryCount>> categories() async => [const CategoryCount('Canh', 10), const CategoryCount('Món kho', 35)];

  @override
  Future<List<RecipeSummary>> featured() async => all.take(3).toList();
}

List<RecipeSummary> sample() => [for (var i = 1; i <= 45; i++) dish(i, i <= 10 ? 'Canh' : 'Món kho')];

void main() {
  group('Home — xem trước', () {
    test('chỉ tải 1 trang xem trước, biết tổng số món để hiện "Xem tất cả"', () async {
      final source = FakeSource(sample());
      final c = HomeController(source: source, fallback: FakeSource([]));
      await c.init();
      expect(c.items, hasLength(HomeController.previewSize));
      expect(c.total, 45);
      expect(c.hasMoreThanPreview, isTrue);
      expect(c.allCount, 45);
      expect(source.requests, ['null#1']);
    });

    test('danh mục ít món hơn phần xem trước → không cần "Xem tất cả"', () async {
      final c = HomeController(source: FakeSource(sample()), fallback: FakeSource([]));
      await c.init();
      await c.selectCategory('Canh');
      expect(c.items, hasLength(10));
      expect(c.hasMoreThanPreview, isFalse);
    });

    test('đổi danh mục liên tục: bỏ kết quả cũ về muộn', () async {
      final source = FakeSource(sample());
      final c = HomeController(source: source, fallback: FakeSource([]));
      await c.init();

      source.gate = Completer();
      final slow = c.selectCategory('Món kho'); // đang chờ
      final switched = c.selectCategory('Canh');
      source.gate!.complete();
      await Future.wait([slow, switched]);

      expect(c.selectedCategory, 'Canh');
      expect(c.items.every((r) => r.category == 'Canh'), isTrue);
      expect(c.total, 10);
    });

    test('server lỗi → dùng nguồn dự phòng, báo ngoại tuyến; "Xem tất cả" dùng chung nguồn đó', () async {
      final c = HomeController(source: FakeSource(sample(), failAlways: true), fallback: FakeSource(sample()));
      await c.init();
      expect(c.isOffline, isTrue);
      expect(c.items, hasLength(HomeController.previewSize));
      expect(c.error, isNull);

      final all = c.openAllController();
      await all.init();
      expect(all.items, hasLength(20));
      expect(all.error, isNull);
      all.dispose();
    });

    test('hiệu ứng xuất hiện chỉ chạy 1 lần cho mỗi món', () {
      final c = HomeController(source: FakeSource([]), fallback: FakeSource([]));
      expect(c.shouldAnimate(1), isTrue);
      expect(c.shouldAnimate(1), isFalse);
    });
  });

  group('Xem tất cả — phân trang', () {
    test('tải từng trang 20 món tới hết', () async {
      final c = RecipeListController(source: FakeSource(sample()), fallback: FakeSource([]));
      await c.init();
      expect(c.items, hasLength(20));
      expect(c.total, 45);
      expect(c.hasMore, isTrue);
      await c.loadMore();
      await c.loadMore();
      expect(c.items, hasLength(45));
      expect(c.hasMore, isFalse);
      await c.loadMore(); // hết rồi thì không gọi nữa
      expect(c.items, hasLength(45));
    });

    test('chỉ lấy món của danh mục được mở', () async {
      final c = RecipeListController(source: FakeSource(sample()), fallback: FakeSource([]), category: 'Canh');
      await c.init();
      expect(c.title, 'Canh');
      expect(c.items.every((r) => r.category == 'Canh'), isTrue);
      expect(c.total, 10);
    });

    test('lỗi ở trang sau → hiện lỗi, bấm thử lại thì tải tiếp', () async {
      final source = FakeSource(sample(), failPage: 2);
      final c = RecipeListController(source: source, fallback: FakeSource([]));
      await c.init();
      await c.loadMore();
      expect(c.error, isNotNull);
      expect(c.items, hasLength(20));
      source.failPage = null;
      await c.retry();
      expect(c.error, isNull);
      expect(c.items, hasLength(40));
    });
  });

  testWidgets('màn Home: lưới xem trước + "Xem tất cả" mở màn danh sách, cuộn tới cuối tự tải trang kế', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final source = FakeSource(sample());
    final controller = HomeController(source: source, fallback: FakeSource([]));
    await tester.pumpWidget(MaterialApp(home: HomeScreen(controller: controller)));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

    expect(find.text('Hôm nay nấu gì?'), findsOneWidget);
    expect(find.byType(RecipeTileCard), findsWidgets);
    expect(find.text('Tất cả món'), findsOneWidget);

    // Home không tự tải thêm khi cuộn.
    await tester.fling(find.byType(CustomScrollView), const Offset(0, -6000), 3000);
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(source.requests, ['null#1']);

    await tester.tap(find.text('Xem tất cả 45 món'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.byType(RecipeListScreen), findsOneWidget);
    expect(source.requests, ['null#1', 'null#1'], reason: 'màn Xem tất cả tải trang 1 (20 món)');

    final listScroll = find.descendant(of: find.byType(RecipeListScreen), matching: find.byType(CustomScrollView));
    await tester.fling(listScroll, const Offset(0, -6000), 3000);
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(source.requests, contains('null#2'), reason: 'cuộn gần cuối phải tải trang 2');

    // Gỡ màn để chắc chắn timer banner / hiệu ứng được huỷ.
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  test('formatCount dùng dấu chấm hàng nghìn', () {
    expect(formatCount(45), '45');
    expect(formatCount(1829), '1.829');
    expect(formatCount(1234567), '1.234.567');
  });
}
