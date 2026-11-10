import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tomato_food_tip/core/data/recipe_repository.dart';
import 'package:tomato_food_tip/features/nutrition/nutrition_advisor_screen.dart';
import 'package:tomato_food_tip/features/nutrition/nutrition_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RecipeRepository.instance.load(online: false);
  });

  const validGeminiJsonText = '''
{
  "targetGroup": "Gia đình (4 người)",
  "healthGoal": "Cân bằng",
  "advisorAdvice": "Chế độ dinh dưỡng cân bằng và đa dạng với các món ăn Việt Nam truyền thống, giàu chất xơ và đạm.",
  "dailyPlans": [
    {
      "dayNumber": 1,
      "dayName": "Thứ Hai",
      "totalCalories": 1850,
      "nutritionSummary": "Năng lượng ổn định cho ngày đầu tuần với phở bò và cá kho.",
      "meals": [
        {
          "mealType": "Bữa sáng",
          "dishName": "Phở bò tái nạm",
          "calories": 480,
          "proteinGrams": 28.0,
          "carbsGrams": 58.0,
          "fatGrams": 14.0,
          "tip": "Ăn kèm chanh tươi và rau húng quế."
        },
        {
          "mealType": "Bữa trưa",
          "dishName": "Cơm cá bống kho tiêu",
          "calories": 650,
          "proteinGrams": 32.0,
          "carbsGrams": 78.0,
          "fatGrams": 18.0,
          "tip": "Kho cá nhỏ lửa để thịt cá săn chắc."
        },
        {
          "mealType": "Bữa tối",
          "dishName": "Canh sườn nấu chua",
          "calories": 520,
          "proteinGrams": 26.0,
          "carbsGrams": 55.0,
          "fatGrams": 16.0,
          "tip": "Ăn trước 19h30 để dễ tiêu hoá."
        }
      ]
    },
    {
      "dayNumber": 2,
      "dayName": "Thứ Ba",
      "totalCalories": 1820,
      "nutritionSummary": "Cung cấp năng lượng hài hoà.",
      "meals": [
        {
          "mealType": "Bữa sáng",
          "dishName": "Bánh mì ốp la",
          "calories": 420,
          "proteinGrams": 18.0,
          "carbsGrams": 46.0,
          "fatGrams": 16.0,
          "tip": "Kèm dưa chuột."
        },
        {
          "mealType": "Bữa trưa",
          "dishName": "Thịt kho trứng cút",
          "calories": 680,
          "proteinGrams": 34.0,
          "carbsGrams": 70.0,
          "fatGrams": 22.0,
          "tip": "Bớt mỡ heo khi ướp thịt."
        },
        {
          "mealType": "Bữa tối",
          "dishName": "Canh mướp đắng nhồi thịt",
          "calories": 490,
          "proteinGrams": 25.0,
          "carbsGrams": 48.0,
          "fatGrams": 15.0,
          "tip": "Giải nhiệt hiệu quả."
        }
      ]
    },
    {
      "dayNumber": 3,
      "dayName": "Thứ Tư",
      "totalCalories": 1800,
      "nutritionSummary": "Giàu vitamin và khoáng chất.",
      "meals": [
        {"mealType": "Bữa sáng", "dishName": "Xôi xéo đỗ xanh", "calories": 450, "proteinGrams": 15.0, "carbsGrams": 65.0, "fatGrams": 12.0, "tip": "Ăn vừa đủ tinh bột."},
        {"mealType": "Bữa trưa", "dishName": "Gà hấp lá chanh", "calories": 620, "proteinGrams": 36.0, "carbsGrams": 60.0, "fatGrams": 16.0, "tip": "Bỏ da gà."},
        {"mealType": "Bữa tối", "dishName": "Tôm xào bông cải", "calories": 480, "proteinGrams": 28.0, "carbsGrams": 45.0, "fatGrams": 14.0, "tip": "Xào nhanh tay."}
      ]
    },
    {
      "dayNumber": 4,
      "dayName": "Thứ Năm",
      "totalCalories": 1810,
      "nutritionSummary": "Cân bằng đạm và tinh bột.",
      "meals": [
        {"mealType": "Bữa sáng", "dishName": "Cháo yến mạch", "calories": 410, "proteinGrams": 26.0, "carbsGrams": 48.0, "fatGrams": 9.0, "tip": "Dễ tiêu hóa."},
        {"mealType": "Bữa trưa", "dishName": "Bò xào ớt chuông", "calories": 640, "proteinGrams": 33.0, "carbsGrams": 66.0, "fatGrams": 18.0, "tip": "Giàu vitamin C."},
        {"mealType": "Bữa tối", "dishName": "Canh chua nghêu", "calories": 460, "proteinGrams": 22.0, "carbsGrams": 50.0, "fatGrams": 12.0, "tip": "Thanh mát."}
      ]
    },
    {
      "dayNumber": 5,
      "dayName": "Thứ Sáu",
      "totalCalories": 1830,
      "nutritionSummary": "Tăng cường omega-3.",
      "meals": [
        {"mealType": "Bữa sáng", "dishName": "Bún mọc nấm", "calories": 440, "proteinGrams": 22.0, "carbsGrams": 54.0, "fatGrams": 13.0, "tip": "Nước dùng thanh."},
        {"mealType": "Bữa trưa", "dishName": "Cá thu sốt cà chua", "calories": 660, "proteinGrams": 35.0, "carbsGrams": 68.0, "fatGrams": 20.0, "tip": "Giàu omega-3."},
        {"mealType": "Bữa tối", "dishName": "Salad ức gà", "calories": 470, "proteinGrams": 30.0, "carbsGrams": 40.0, "fatGrams": 15.0, "tip": "Nhẹ bụng."}
      ]
    },
    {
      "dayNumber": 6,
      "dayName": "Thứ Bảy",
      "totalCalories": 1890,
      "nutritionSummary": "Thực đơn cuối tuần tươi ngon.",
      "meals": [
        {"mealType": "Bữa sáng", "dishName": "Bánh cuốn nóng", "calories": 460, "proteinGrams": 19.0, "carbsGrams": 60.0, "fatGrams": 14.0, "tip": "Ăn rau thơm."},
        {"mealType": "Bữa trưa", "dishName": "Gà luộc lá chanh", "calories": 710, "proteinGrams": 40.0, "carbsGrams": 72.0, "fatGrams": 22.0, "tip": "Thịt gà ngọt."},
        {"mealType": "Bữa tối", "dishName": "Cháo cá hồi", "calories": 500, "proteinGrams": 27.0, "carbsGrams": 56.0, "fatGrams": 14.0, "tip": "Hạt sen an thần."}
      ]
    },
    {
      "dayNumber": 7,
      "dayName": "Chủ nhật",
      "totalCalories": 1820,
      "nutritionSummary": "Tái tạo năng lượng cho tuần mới.",
      "meals": [
        {"mealType": "Bữa sáng", "dishName": "Hủ tiếu Nam Vang", "calories": 460, "proteinGrams": 24.0, "carbsGrams": 56.0, "fatGrams": 13.0, "tip": "Thêm giá hẹ."},
        {"mealType": "Bữa trưa", "dishName": "Sườn chua ngọt", "calories": 680, "proteinGrams": 34.0, "carbsGrams": 70.0, "fatGrams": 20.0, "tip": "Canh cua rau đay."},
        {"mealType": "Bữa tối", "dishName": "Bún chay thanh đạm", "calories": 460, "proteinGrams": 20.0, "carbsGrams": 58.0, "fatGrams": 12.0, "tip": "Nhẹ nhàng ngủ ngon."}
      ]
    }
  ]
}
''';

  final validGeminiResponseBody = jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': validGeminiJsonText}
          ]
        }
      }
    ]
  });

  group('NutritionController Direct Gemini REST API Integration', () {
    test('generatePlan sends direct Gemini HTTP POST and parses 7-day MealPlan', () async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          validGeminiResponseBody,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-gemini-api-key',
        model: 'gemini-1.5-flash',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      );

      // Verify initial state
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.currentPlan.dailyPlans.length, equals(7));

      // Execute generatePlan
      final success = await controller.generatePlan();

      // Assert success and state transitions
      expect(success, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.selectedDayIndex, equals(0));

      // Assert HTTP request details
      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, equals('POST'));
      expect(
        capturedRequest!.url.toString(),
        equals('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent'),
      );
      expect(capturedRequest!.headers['x-goog-api-key'], equals('test-gemini-api-key'));
      expect(capturedRequest!.headers['content-type'], contains('application/json'));

      final requestJson = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(requestJson['generationConfig']['responseMimeType'], equals('application/json'));

      final promptText = requestJson['contents'][0]['parts'][0]['text'] as String;
      expect(promptText, contains('Gia đình (4 người)'));
      expect(promptText, contains('Cân bằng'));

      // Assert parsed MealPlan
      final plan = controller.currentPlan;
      expect(plan.targetGroup, equals('Gia đình (4 người)'));
      expect(plan.healthGoal, equals('Cân bằng'));
      expect(plan.totalDays, equals(7));
      expect(plan.dailyPlans.length, equals(7));
      expect(plan.advisorAdvice, contains('Chế độ dinh dưỡng cân bằng'));

      final monday = plan.dailyPlans[0];
      expect(monday.dayName, equals('Thứ Hai'));
      expect(monday.totalCalories, equals(1850));
      expect(monday.meals.length, equals(3));
      expect(monday.meals[0].dishName, equals('Phở bò tái nạm'));
      expect(monday.meals[0].calories, equals(480));
      expect(monday.meals[0].proteinGrams, equals(28.0));
      expect(monday.meals[0].tip, contains('chanh tươi'));

      controller.dispose();
    });

    test('generatePlan does not use fakeGenerateDelay and completes quickly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          validGeminiResponseBody,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'fast-key',
      );

      final stopwatch = Stopwatch()..start();
      final success = await controller.generatePlan();
      stopwatch.stop();

      expect(success, isTrue);
      // With fake delay of 600ms removed, mock client completes in under 300ms
      expect(stopwatch.elapsedMilliseconds, lessThan(400));

      controller.dispose();
    });

    test('generatePlan handles HTTP 429 quota exhausted gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 429,
              'message': 'Quota exceeded for quota metric generate_content_requests.',
              'status': 'RESOURCE_EXHAUSTED',
            }
          }),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'quota-key',
      );

      final success = await controller.generatePlan();

      expect(success, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('429'));

      controller.dispose();
    });

    test('generatePlan handles HTTP 500 server error gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'error-key',
      );

      final success = await controller.generatePlan();

      expect(success, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('500'));

      controller.dispose();
    });

    test('generatePlan handles network ClientException gracefully', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection reset by peer');
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'disconnect-key',
      );

      final success = await controller.generatePlan();

      expect(success, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('kết nối'));

      controller.dispose();
    });

    test('generatePlan handles empty API key gracefully', () async {
      final controller = NutritionController(
        apiKey: '',
      );

      final success = await controller.generatePlan();

      expect(success, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('GEMINI_API_KEY'));

      controller.dispose();
    });

    test('generatePlan handles invalid JSON format response gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Not a valid JSON plan content'}
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'bad-json-key',
      );

      final success = await controller.generatePlan();

      expect(success, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);

      controller.dispose();
    });

    test('uses gemini-3.8-flash by default and rotates across multiple keys on HTTP 429', () async {
      final usedKeys = <String>[];
      Uri? capturedUrl;

      final mockClient = MockClient((request) async {
        capturedUrl = request.url;
        final key = request.headers['x-goog-api-key']!;
        usedKeys.add(key);
        if (key == 'key-1') {
          return http.Response(
            jsonEncode({'error': {'message': 'Rate limit'}}),
            429,
            headers: {'content-type': 'application/json', 'retry-after': '60'},
          );
        }
        return http.Response(
          validGeminiResponseBody,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'key-1, key-2',
      );

      final first = await controller.generatePlan();
      expect(first, isTrue);
      expect(
        capturedUrl.toString(),
        contains('/models/gemini-3.8-flash:generateContent'),
      );

      final second = await controller.generatePlan();
      expect(second, isTrue);
      expect(usedKeys, equals(['key-1', 'key-2', 'key-2']));

      controller.dispose();
    });
  });

  group('NutritionAdvisorScreen UI and Error Handling SnackBar', () {
    testWidgets('shows success SnackBar when generatePlan succeeds', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          validGeminiResponseBody,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'success-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NutritionAdvisorScreen(controller: controller),
        ),
      );

      expect(find.text('Dinh Dưỡng & Thực Đơn AI'), findsOneWidget);
      expect(find.text('Tạo lại thực đơn thông minh'), findsOneWidget);

      await tester.tap(find.text('Tạo lại thực đơn thông minh'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Đã tạo thành công thực đơn'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('shows red error SnackBar when generatePlan fails', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Quota exceeded (429)'}
          }),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'fail-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NutritionAdvisorScreen(controller: controller),
        ),
      );

      await tester.tap(find.text('Tạo lại thực đơn thông minh'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Quota exceeded (429)'), findsOneWidget);

      controller.dispose();
    });
  });
}
