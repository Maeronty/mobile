// Test luồng "ảnh → nguyên liệu → món": tìm món dùng `/api/suggest` (so khớp
// trong database, không AI), khách vẫn tìm được; chỉ nhận diện ảnh cần đăng nhập.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tomato_food_tip/core/data/api_client.dart';
import 'package:tomato_food_tip/features/suggest/ai_suggest_controller.dart';

void main() {
  test('tìm món gọi /api/suggest (không gọi AI), khách cũng dùng được', () async {
    final calls = <String>[];
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        calls.add(req.url.path);
        expect(jsonDecode(req.body), {'ingredients': ['trứng', 'cà chua']});
        return http.Response.bytes(
          utf8.encode(jsonEncode([
            {'id': 1000015, 'title': 'Trứng chiên cà chua', 'reason': 'Tận dụng trứng và cà chua bạn đang có.', 'used': ['trứng', 'cà chua'], 'missing': ['Hành lá']},
          ])),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final c = AiSuggestController(initialIngredients: ['trứng', 'cà chua', 'Trứng'], api: api);
    expect(c.requiresLogin, isTrue, reason: 'test chạy ở chế độ khách');

    await c.suggest();

    expect(calls, ['/api/suggest']);
    expect(c.results.single.id, 1000015);
    expect(c.results.single.missing, ['Hành lá']);
    expect(c.message, isNull);
  });

  test('khách không gửi ảnh lên nhận diện', () async {
    final calls = <String>[];
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        calls.add(req.url.path);
        return http.Response('[]', 200);
      }),
    );
    final c = AiSuggestController(api: api);
    final jpeg = Uint8List.fromList([0xff, 0xd8, ...List.filled(20, 0)]);

    await c.analyzeImage(jpeg);

    expect(calls, isEmpty);
    expect(c.message, contains('đăng nhập'));
  });
}
