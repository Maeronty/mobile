// Test Cooking Mode: giọng đọc hướng dẫn (đọc bước hiện tại, tự đọc khi chuyển
// bước, báo lỗi khi máy không có giọng tiếng Việt, im khi thoát màn).

import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/core/models/recipe.dart';
import 'package:tomato_food_tip/features/cooking_mode/cooking_mode_controller.dart';
import 'package:tomato_food_tip/features/cooking_mode/cooking_voice.dart';

class FakeVoice implements CookingVoice {
  FakeVoice({this.available = true});
  final bool available;
  final spoken = <String>[];
  int stops = 0;

  @override
  Future<bool> speak(String text) async {
    if (!available) return false;
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async => stops++;
}

Recipe recipe() => const Recipe(
      id: 1,
      title: 'Trứng chiên',
      description: '',
      imageAsset: '',
      category: 'Món chiên',
      tags: [],
      cookTimeMinutes: 10,
      difficulty: 'Dễ',
      servings: 2,
      calories: 0,
      averageRating: 0,
      totalRatings: 0,
      ingredients: [],
      instructions: [
        InstructionStep(stepNumber: 1, description: 'Đập trứng ra bát.', estimatedMinutes: 1),
        InstructionStep(stepNumber: 2, description: 'Chiên vàng hai mặt.', estimatedMinutes: 1, tip: 'Để lửa vừa.'),
      ],
      nutrition: NutritionInfo(calories: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0),
    );

void main() {
  test('bật loa → đọc bước hiện tại; chuyển bước → tự đọc bước mới; tắt → im', () async {
    final voice = FakeVoice();
    final c = CookingModeController(recipe: recipe(), voice: voice);

    expect(await c.toggleVoice(), isNull);
    expect(c.isVoiceOn, isTrue);
    expect(voice.spoken.last, 'Bước 1 trên 2. Đập trứng ra bát.');

    c.nextStep();
    expect(voice.spoken.last, 'Bước 2 trên 2. Chiên vàng hai mặt. Mẹo: Để lửa vừa.');

    await c.toggleVoice();
    expect(c.isVoiceOn, isFalse);
    expect(voice.stops, 1);

    c.prevStep();
    expect(voice.spoken, hasLength(2), reason: 'đã tắt loa thì không đọc nữa');
    c.dispose();
  });

  test('máy không có giọng tiếng Việt → tự tắt loa và trả câu hướng dẫn cài', () async {
    final c = CookingModeController(recipe: recipe(), voice: FakeVoice(available: false));
    expect(await c.toggleVoice(), CookingModeController.voiceUnavailableMessage);
    expect(c.isVoiceOn, isFalse);
    c.dispose();
  });

  test('thoát màn → tắt giọng đọc', () {
    final voice = FakeVoice();
    CookingModeController(recipe: recipe(), voice: voice).dispose();
    expect(voice.stops, 1);
  });
}
