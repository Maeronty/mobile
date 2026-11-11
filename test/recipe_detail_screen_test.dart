// Test màn chi tiết tải theo id: hiện ngay ảnh/tên từ bản tóm tắt, khung chờ
// trong lúc tải, rồi nội dung đầy đủ (JSON giống `GET /api/Recipes/:id` của Rust).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tomato_food_tip/core/data/api_client.dart';
import 'package:tomato_food_tip/core/models/recipe_summary.dart';
import 'package:tomato_food_tip/features/recipe_detail/recipe_detail_controller.dart';
import 'package:tomato_food_tip/features/recipe_detail/recipe_detail_screen.dart';

const detailJson = {
  'recipeId': 1001399, 'recipeID': 1001399, 'id': 1001399,
  'title': 'Phở Bò Bắp Hoa',
  'description': 'Công thức Phở Bò Bắp Hoa theo Món Ngon Mỗi Ngày.',
  'imageUrl': '', 'additionalImages': [],
  'cookTimeMinutes': 0, 'difficulty': 'Nâng cao', 'servings': 0, 'calories': 0,
  'averageRating': 0.0, 'totalRatings': 0, 'userRating': null,
  'authorName': 'Món Ngon Mỗi Ngày', 'source': 'Món Ngon Mỗi Ngày',
  'ingredients': [
    {'name': 'Thịt bò bắp hoa', 'amount': 300.0, 'unit': 'g', 'notes': null},
    {'name': 'Muối, tiêu', 'amount': 0.0, 'unit': '', 'notes': null},
  ],
  'instructions': [
    // Server chỉ trả phút cho bước CÓ ghi thời gian ("ướp 30 phút"); bước này không ghi.
    {'stepNumber': 1, 'title': null, 'content': 'Sơ chế: Rửa sạch thịt.', 'imageUrl': null, 'estimatedMinutes': null},
  ],
  'nutrition': null,
  'tags': ['Bún, Phở & Mì'],
  'isFavorited': false,
};

void main() {
  testWidgets('hiện ngay tên từ preview, tải xong hiện nguyên liệu và các bước', (tester) async {
    final gate = Completer<void>();
    String? requestedPath;
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        requestedPath = req.url.path;
        await gate.future;
        return http.Response.bytes(utf8.encode(jsonEncode(detailJson)), 200);
      }),
    );
    final controller = RecipeDetailController(recipeId: 1001399, api: api);
    const preview = RecipeSummary(
      id: 1001399, title: 'Phở Bò Bắp Hoa', image: '', category: 'Bún, Phở & Mì',
      source: 'Món Ngon Mỗi Ngày', cookTimeMinutes: 0, calories: 0, ingredientCount: 2,
    );

    await tester.pumpWidget(MaterialApp(
      home: RecipeDetailScreen(recipeId: 1001399, preview: preview, heroTag: 't', controller: controller),
    ));
    await tester.pump();
    expect(find.text('Phở Bò Bắp Hoa'), findsWidgets, reason: 'tên có ngay từ preview');
    expect(find.text('Thịt bò bắp hoa'), findsNothing, reason: 'đang tải');

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Thịt bò bắp hoa', skipOffstage: false), findsOneWidget);
    expect(find.text('Sơ chế: Rửa sạch thịt.', skipOffstage: false), findsOneWidget);
    expect(find.text('Chưa có dữ liệu dinh dưỡng cho món này.', skipOffstage: false), findsOneWidget);
    expect(requestedPath, '/api/Recipes/1001399');
    expect(controller.recipe!.difficulty, 'Khó');
    expect(controller.recipe!.instructions.single.estimatedMinutes, isNull, reason: 'không rõ thời gian thì không bịa phút');

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
