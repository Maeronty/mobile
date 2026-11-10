// =============================================================================
// NGUỒN DỮ LIỆU DANH SÁCH MÓN CÓ PHÂN TRANG (RecipeFeedSource)
// =============================================================================
//
// HAI NGUỒN, CÙNG MỘT GIAO DIỆN
//   - ApiRecipeFeedSource   : gọi server Rust, mỗi lần 1 trang (vài KB).
//       GET /api/Recipes/page?page=&pageSize=&category=
//       GET /api/Recipes/categories
//       GET /api/Recipes/featured
//   - LocalRecipeFeedSource : dự phòng khi không gọi được server — phân trang
//     ngay trên danh mục đóng gói sẵn trong app (RecipeRepository), cùng thứ
//     tự và cùng cách sắp danh mục như server.
//
// HomeController chỉ biết RecipeFeedSource, không cần biết dữ liệu đến từ đâu.
// =============================================================================

import '../models/recipe_summary.dart';
import 'api_client.dart';
import 'recipe_repository.dart';

abstract class RecipeFeedSource {
  Future<RecipePage> page({required int page, required int pageSize, String? category});
  Future<List<CategoryCount>> categories();
  Future<List<RecipeSummary>> featured();
}

class ApiRecipeFeedSource implements RecipeFeedSource {
  final ApiClient api;

  ApiRecipeFeedSource([ApiClient? api]) : api = api ?? ApiClient.instance;

  @override
  Future<RecipePage> page({required int page, required int pageSize, String? category}) async {
    final query = Uri(queryParameters: {
      'page': '$page',
      'pageSize': '$pageSize',
      'category': ?category,
    }).query;
    final data = await api.get('/api/Recipes/page?$query', timeout: const Duration(seconds: 8));
    return RecipePage.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<CategoryCount>> categories() async {
    final data = await api.get('/api/Recipes/categories', timeout: const Duration(seconds: 8));
    return [for (final x in data as List) CategoryCount.fromJson(x as Map<String, dynamic>)];
  }

  @override
  Future<List<RecipeSummary>> featured() async {
    final data = await api.get('/api/Recipes/featured', timeout: const Duration(seconds: 8));
    return [for (final x in data as List) RecipeSummary.fromJson(x as Map<String, dynamic>)];
  }
}

class LocalRecipeFeedSource implements RecipeFeedSource {
  static const _featuredCategories = ['Bún, Phở & Mì', 'Canh', 'Món kho', 'Cơm & Xôi', 'Gỏi & Salad'];

  Future<List<RecipeSummary>> _all() async {
    await RecipeRepository.instance.ensureLoaded();
    return RecipeRepository.instance.all.map(RecipeSummary.fromRecipe).toList();
  }

  @override
  Future<RecipePage> page({required int page, required int pageSize, String? category}) async {
    final all = await _all();
    final filtered = category == null ? all : all.where((r) => r.category == category).toList();
    final start = (page - 1) * pageSize;
    final items = filtered.skip(start).take(pageSize).toList();
    return RecipePage(items: items, page: page, total: filtered.length, hasMore: start + items.length < filtered.length);
  }

  @override
  Future<List<CategoryCount>> categories() async {
    await RecipeRepository.instance.ensureLoaded();
    final repo = RecipeRepository.instance;
    final counts = <String, int>{};
    for (final r in repo.all) {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    }
    return [for (final name in repo.categories) CategoryCount(name, counts[name] ?? 0)];
  }

  @override
  Future<List<RecipeSummary>> featured() async {
    final all = (await _all()).where((r) => r.image.isNotEmpty).toList();
    return [
      for (final c in _featuredCategories) ...all.where((r) => r.category == c).take(1),
    ];
  }
}
