import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  http.Response makeGeminiHttpResponse(String text, {int statusCode = 200}) {
    final jsonStr = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    });
    return http.Response.bytes(
      utf8.encode(jsonStr),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  http.Response makeRawHttpResponse(String rawBody, {int statusCode = 200}) {
    return http.Response.bytes(
      utf8.encode(rawBody),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  const validPlanJson = '''
{
  "targetGroup": "Cá nhân",
  "healthGoal": "Giảm cân",
  "advisorAdvice": "Uống 2 lít nước mỗi ngày và hạn chế đường tinh luyện.",
  "dailyPlans": [
    {
      "dayNumber": 1,
      "dayName": "Thứ Hai",
      "totalCalories": 1500,
      "nutritionSummary": "Thực đơn thanh đạm giảm calo.",
      "meals": [
        {
          "mealType": "Bữa sáng",
          "dishName": "Yến mạch chuối",
          "calories": 350,
          "proteinGrams": 15.0,
          "carbsGrams": 45.0,
          "fatGrams": 6.0,
          "tip": "Không thêm sữa đặc."
        }
      ]
    }
  ]
}
''';

  group('Adversarial Test: HTTP Status Codes & Server Failures', () {
    final statusCodesToTest = [
      {'code': 400, 'body': '{"error": {"code": 400, "message": "Bad Request: invalid payload"}}'},
      {'code': 401, 'body': '{"error": {"code": 401, "message": "API key not valid. Please pass a valid API key."}}'},
      {'code': 403, 'body': '{"error": {"code": 403, "message": "Permission denied: quota or IAM issue"}}'},
      {'code': 429, 'body': '{"error": {"code": 429, "message": "Resource has been exhausted (e.g. check quota)."}}'},
      {'code': 500, 'body': 'Internal Server Error'},
      {'code': 502, 'body': '<html><body>502 Bad Gateway nginx</body></html>'},
      {'code': 503, 'body': 'Service Unavailable: model overloaded'},
      {'code': 504, 'body': 'Gateway Timeout'},
    ];

    for (final testCase in statusCodesToTest) {
      final code = testCase['code'] as int;
      final body = testCase['body'] as String;

      test('handles HTTP $code correctly without unhandled exceptions', () async {
        final mockClient = MockClient((request) async {
          return makeRawHttpResponse(body, statusCode: code);
        });

        final controller = NutritionController(
          client: mockClient,
          apiKey: 'test-key',
        );

        final result = await controller.generatePlan();

        expect(result, isFalse, reason: 'generatePlan should return false on HTTP $code');
        expect(controller.isLoading, isFalse, reason: 'isLoading must reset to false on HTTP $code');
        expect(controller.errorMessage, isNotNull, reason: 'errorMessage must be set on HTTP $code');
        expect(controller.errorMessage!.isNotEmpty, isTrue);

        controller.dispose();
      });
    }
  });

  group('Adversarial Test: Slow Connection, Timeouts, and Network Drops', () {
    test('handles SocketException (no internet / DNS failure) gracefully', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Failed host lookup: generativelanguage.googleapis.com');
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('kết nối'));

      controller.dispose();
    });

    test('handles http.ClientException (connection abort / reset) gracefully', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection abruptly closed by peer');
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('kết nối'));

      controller.dispose();
    });

    test('handles TimeoutException gracefully', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Request to Gemini API timed out after 45 seconds');
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('thời gian chờ'));

      controller.dispose();
    });
  });

  group('Adversarial Test: Truncated, Malformed, or Non-conforming JSON Responses', () {
    test('handles truncated HTTP response body', () async {
      final mockClient = MockClient((request) async {
        return makeRawHttpResponse('{"candidates": [{"content": {"parts": [{"tex', statusCode: 200);
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);

      controller.dispose();
    });

    test('handles response with empty candidates array', () async {
      final mockClient = MockClient((request) async {
        return makeRawHttpResponse(jsonEncode({'candidates': []}), statusCode: 200);
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('Gemini không trả về kết quả nào'));

      controller.dispose();
    });

    test('handles response with candidate missing content or parts', () async {
      final mockClient = MockClient((request) async {
        return makeRawHttpResponse(
          jsonEncode({
            'candidates': [
              {'content': {'parts': []}}
            ]
          }),
          statusCode: 200,
        );
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('trống'));

      controller.dispose();
    });

    test('handles candidates containing thought: true parts only', () async {
      final mockClient = MockClient((request) async {
        return makeRawHttpResponse(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'thought': true, 'text': 'I am thinking about Vietnamese food...'}
                  ]
                }
              }
            ]
          }),
          statusCode: 200,
        );
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);

      controller.dispose();
    });

    test('handles parts with mix of thought: true and valid JSON text', () async {
      final mockClient = MockClient((request) async {
        return makeRawHttpResponse(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'thought': true, 'text': 'Thinking process...'},
                    {'thought': false, 'text': validPlanJson}
                  ]
                }
              }
            ]
          }),
          statusCode: 200,
        );
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isTrue, reason: 'Error: ${controller.errorMessage}');
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.currentPlan.dailyPlans.length, equals(1));
      expect(controller.currentPlan.dailyPlans[0].meals[0].dishName, equals('Yến mạch chuối'));

      controller.dispose();
    });

    test('handles markdown wrapped JSON (```json ... ```)', () async {
      final wrappedJson = '```json\n$validPlanJson\n```';
      final mockClient = MockClient((request) async {
        return makeGeminiHttpResponse(wrappedJson);
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isTrue, reason: 'Error: ${controller.errorMessage}');
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.currentPlan.dailyPlans.length, equals(1));

      controller.dispose();
    });

    test('handles empty JSON object {} in Gemini response text', () async {
      final mockClient = MockClient((request) async {
        return makeGeminiHttpResponse('{}');
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('Không tìm thấy kế hoạch ngày hợp lệ'));

      controller.dispose();
    });

    test('handles dailyPlans with empty meals list and missing fields safely', () async {
      const jsonWithEmptyMeals = '''
{
  "targetGroup": "Cặp đôi",
  "dailyPlans": [
    {
      "dayNumber": 1,
      "dayName": "Thứ Hai",
      "meals": []
    }
  ]
}
''';
      final mockClient = MockClient((request) async {
        return makeGeminiHttpResponse(jsonWithEmptyMeals);
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isTrue, reason: 'Error: ${controller.errorMessage}');
      expect(controller.isLoading, isFalse);
      expect(controller.currentPlan.dailyPlans.length, equals(1));
      expect(controller.currentPlan.dailyPlans[0].meals.isEmpty, isTrue);
      expect(controller.currentPlan.dailyPlans[0].totalCalories, equals(0));
      expect(controller.currentPlan.advisorAdvice, isNotEmpty);

      controller.dispose();
    });

    test('handles macro numbers as nulls with safe fallback defaults', () async {
      const jsonWithNullMacros = '''
{
  "dailyPlans": [
    {
      "dayNumber": 1,
      "dayName": "Thứ Hai",
      "meals": [
        {
          "dishName": "Canh rau ngót",
          "calories": null,
          "proteinGrams": null,
          "carbsGrams": null,
          "fatGrams": null,
          "tip": null
        }
      ]
    }
  ]
}
''';
      final mockClient = MockClient((request) async {
        return makeGeminiHttpResponse(jsonWithNullMacros);
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      expect(result, isTrue, reason: 'Error: ${controller.errorMessage}');
      expect(controller.isLoading, isFalse);
      final meal = controller.currentPlan.dailyPlans[0].meals[0];
      expect(meal.dishName, equals('Canh rau ngót'));
      expect(meal.calories, equals(450));
      expect(meal.proteinGrams, equals(20.0));
      expect(meal.carbsGrams, equals(50.0));
      expect(meal.fatGrams, equals(12.0));
      expect(meal.tip, isNotEmpty);

      controller.dispose();
    });

    test('handles macro numbers as strings without unhandled crash', () async {
      const jsonWithStringMacros = '''
{
  "dailyPlans": [
    {
      "dayNumber": 1,
      "dayName": "Thứ Hai",
      "meals": [
        {
          "dishName": "Phở gà",
          "calories": "500",
          "proteinGrams": "25.0"
        }
      ]
    }
  ]
}
''';
      final mockClient = MockClient((request) async {
        return makeGeminiHttpResponse(jsonWithStringMacros);
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final result = await controller.generatePlan();

      // If String is passed where num is expected, TypeError is caught gracefully
      expect(result, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);

      controller.dispose();
    });
  });

  group('Adversarial Test: Concurrent Calls & Lifecycle Disposal In-Flight', () {
    test('calling generatePlan repeatedly while in-flight does not leave isLoading stuck or crash', () async {
      var callCount = 0;
      final completer1 = Completer<http.Response>();
      final completer2 = Completer<http.Response>();

      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return completer1.future;
        } else {
          return completer2.future;
        }
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      // Fire call 1
      final future1 = controller.generatePlan();
      expect(controller.isLoading, isTrue);

      // Fire call 2 while call 1 is still awaiting response
      final future2 = controller.generatePlan();
      expect(controller.isLoading, isTrue);

      // Complete call 2 first, then call 1
      completer2.complete(makeGeminiHttpResponse(validPlanJson));
      final res2 = await future2;

      completer1.complete(makeRawHttpResponse('{"error": "Failed"}', statusCode: 500));
      final res1 = await future1;

      expect(controller.isLoading, isFalse);
      expect(res1, isFalse);
      expect(res2, isTrue);

      controller.dispose();
    });

    test('disposing controller while request is in-flight does not throw FlutterError', () async {
      final completer = Completer<http.Response>();

      final mockClient = MockClient((request) => completer.future);

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final future = controller.generatePlan();
      expect(controller.isLoading, isTrue);

      var notifiedAfterDispose = false;
      controller.addListener(() {
        notifiedAfterDispose = true;
      });

      // Dispose controller while request is still pending
      controller.dispose();

      // Complete HTTP response after disposal
      completer.complete(makeGeminiHttpResponse(validPlanJson));

      final result = await future;

      // Must return false and not notify after dispose
      expect(result, isFalse);
      expect(notifiedAfterDispose, isFalse);
    });

    test('disposing controller when HTTP throws an exception does not throw FlutterError', () async {
      final completer = Completer<http.Response>();

      final mockClient = MockClient((request) => completer.future);

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      final future = controller.generatePlan();
      expect(controller.isLoading, isTrue);

      // Allow request to register in the client
      await Future<void>.delayed(Duration.zero);

      // Dispose controller while in-flight
      controller.dispose();

      // Complete with error after disposal
      completer.completeError(const SocketException('Lost connection'));

      final result = await future;
      expect(result, isFalse);
    });
  });

  group('Adversarial Test: NutritionAdvisorScreen Lifecycle & Widget Stress', () {
    testWidgets('unmounting NutritionAdvisorScreen while generatePlan is pending does not throw', (tester) async {
      final completer = Completer<http.Response>();

      final mockClient = MockClient((request) async {
        return completer.future;
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NutritionAdvisorScreen(controller: controller),
        ),
      );

      // Tap generate button
      await tester.tap(find.text('Tạo lại thực đơn thông minh'));
      await tester.pump(); // Start request, show spinner

      expect(controller.isLoading, isTrue);

      // Navigate away / replace screen with empty container while request is in flight
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Different Screen')),
        ),
      );
      await tester.pump();

      // Now complete the response
      completer.complete(makeGeminiHttpResponse(validPlanJson));
      await tester.pumpAndSettle();

      // Must not throw any exception about setState or ScaffoldMessenger on unmounted widget
      expect(find.text('Different Screen'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('rapidly toggling options while plan is loaded updates activeDayPlan seamlessly', (tester) async {
      final mockClient = MockClient((request) async {
        return makeGeminiHttpResponse(validPlanJson);
      });

      final controller = NutritionController(
        client: mockClient,
        apiKey: 'test-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NutritionAdvisorScreen(controller: controller),
        ),
      );

      // Switch target groups
      controller.selectTargetGroup('Đại gia đình');
      controller.selectHealthGoal('Eat Clean');
      await tester.pumpAndSettle();

      expect(controller.selectedTargetGroup, equals('Đại gia đình'));
      expect(controller.selectedHealthGoal, equals('Eat Clean'));

      // Switch days
      controller.selectDay(2);
      await tester.pumpAndSettle();
      expect(controller.selectedDayIndex, equals(2));

      controller.dispose();
    });
  });
}
