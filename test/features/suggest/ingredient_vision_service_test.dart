import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tomato_food_tip/core/services/gemini_api_client.dart';
import 'package:tomato_food_tip/features/kitchen_bag/pantry_controller.dart';
import 'package:tomato_food_tip/features/suggest/ai_suggest_screen.dart';
import 'package:tomato_food_tip/features/suggest/ingredient_camera_scanner_screen.dart';
import 'package:tomato_food_tip/features/suggest/ingredient_vision_service.dart';

Uint8List _sampleJpegBytes() => Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      0xe0,
      0x00,
      0x10,
      0x4a,
      0x46,
      0x49,
      0x46,
      0x00,
      0x01,
    ]);

Uint8List _samplePngBytes() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IngredientVisionService validation', () {
    test('detects JPEG, PNG, WebP and rejects invalid formats or >3MB', () {
      expect(
        IngredientVisionService.validateBytes(_sampleJpegBytes()).mime,
        equals('image/jpeg'),
      );
      expect(
        IngredientVisionService.validateBytes(_samplePngBytes()).mime,
        equals('image/png'),
      );

      final webp = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, //
        0x57, 0x45, 0x42, 0x50,
      ]);
      expect(
        IngredientVisionService.validateBytes(webp).mime,
        equals('image/webp'),
      );

      expect(
        () => IngredientVisionService.validateBytes(Uint8List.fromList([1, 2, 3, 4])),
        throwsFormatException,
      );

      final oversized = Uint8List(IngredientVisionService.maxImageBytes + 1);
      oversized[0] = 0xff;
      oversized[1] = 0xd8;
      expect(
        () => IngredientVisionService.validateBytes(oversized),
        throwsFormatException,
      );
    });
  });

  group('IngredientVisionService direct Gemini 3.8 Flash Vision + fallback', () {
    test('calls direct Gemini Vision with inline_data and rotates keys on 429', () async {
      final usedKeys = <String>[];
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        final key = request.headers['x-goog-api-key'] ?? '';
        usedKeys.add(key);
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        if (key == 'key-1') {
          return http.Response(
            jsonEncode({'error': {'message': 'Rate limited'}}),
            429,
            headers: {'content-type': 'application/json', 'retry-after': '60'},
          );
        }

        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'thought': true, 'text': 'Scanning image...'},
                      {'text': '["Cà chua", "trứng gà", "Cà chua", "  "]'},
                    ],
                  },
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = IngredientVisionService(
        geminiClient: GeminiApiClient(
          client: mockClient,
          apiKey: 'key-1, key-2',
        ),
        httpClient: mockClient,
      );

      final found = await service.recognizeIngredients(
        ScannedImage(bytes: _sampleJpegBytes(), mime: 'image/jpeg'),
      );

      expect(
        capturedUri.toString(),
        contains('/models/gemini-3.8-flash:generateContent'),
      );
      final parts = capturedBody!['contents'][0]['parts'] as List;
      expect(parts[1]['inline_data']['mime_type'], equals('image/jpeg'));
      expect(usedKeys, equals(['key-1', 'key-2']));
      expect(found, equals(['Cà chua', 'trứng gà']));

      service.dispose();
    });

    test('falls back to backend /recognize when direct Gemini fails', () async {
      final calls = <String>[];
      final mockClient = MockClient((request) async {
        calls.add(request.url.toString());
        if (request.url.host == 'generativelanguage.googleapis.com') {
          return http.Response('Service Unavailable', 503);
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode(['Hành lá', 'Thịt bò'])),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = IngredientVisionService(
        geminiClient: GeminiApiClient(client: mockClient, apiKey: 'key-1'),
        httpClient: mockClient,
        backendBaseUrl: 'http://127.0.0.1:8787',
      );

      final found = await service.recognizeIngredients(
        ScannedImage(bytes: _samplePngBytes(), mime: 'image/png'),
      );

      expect(calls.length, equals(2));
      expect(calls[1], equals('http://127.0.0.1:8787/recognize'));
      expect(found, equals(['Hành lá', 'Thịt bò']));

      service.dispose();
    });
  });

  group('IngredientCameraScannerScreen & AiSuggestScreen camera scan UI', () {
    testWidgets('scanner shows fallback and returns gallery XFile when camera unavailable',
        (tester) async {
      XFile? poppedResult;
      final fakeFile = XFile.fromData(
        _sampleJpegBytes(),
        mimeType: 'image/jpeg',
        name: 'scan.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  poppedResult = await Navigator.push<XFile?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IngredientCameraScannerScreen(
                        loadCameras: () async => [],
                        onPickFromGallery: () async => fakeFile,
                      ),
                    ),
                  );
                },
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      expect(find.text('Thử lại mở camera'), findsOneWidget);
      expect(find.text('Chọn ảnh từ thư viện'), findsOneWidget);

      await tester.tap(find.text('Chọn ảnh từ thư viện'));
      await tester.pumpAndSettle();

      expect(poppedResult, isNotNull);
    });

    testWidgets('AiSuggestScreen scans via camera, displays chips, and saves to pantry',
        (tester) async {
      PantryController.instance.clear();
      final scannedBytes = _samplePngBytes();
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '["Cà chua", "Trứng gà"]'},
                    ],
                  },
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = IngredientVisionService(
        geminiClient: GeminiApiClient(client: mockClient, apiKey: 'test-key'),
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestScreen(
            ingredients: const [],
            visionService: service,
            onScanWithCamera: () async => XFile.fromData(
              scannedBytes,
              mimeType: 'image/png',
              name: 'fridge.png',
            ),
          ),
        ),
      );

      await tester.tap(find.text('Quét bằng Camera'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gemini nhận diện: Cà chua, Trứng gà'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Cà chua'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Trứng gà'), findsOneWidget);

      await tester.tap(find.text('Lưu vào Tủ lạnh'));
      await tester.pumpAndSettle();

      expect(PantryController.instance.ingredients, containsAll(['Cà chua', 'Trứng gà']));
      service.dispose();
    });
  });
}
