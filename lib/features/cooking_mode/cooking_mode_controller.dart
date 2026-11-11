// =============================================================================
// FEATURE: CHẾ ĐỘ NẤU RẢNH TAY TỪNG BƯỚC (Step-by-Step Cooking Mode)
// =============================================================================
//
// VAI TRÒ
//   Điều khiển 1 phiên nấu ăn: bước hiện tại và giọng đọc hướng dẫn
//   (CookingVoice). Không có đồng hồ đếm ngược.
//
// FLOW
//   1. Khởi tạo → đứng ở bước 0, giọng đọc tắt.
//
//   2. CHUYỂN BƯỚC:
//        - `nextStep()`: chưa phải bước cuối → sang bước kế, trả về `true`.
//          Đang ở bước cuối → trả về `false` để UI hiện dialog
//          "Chúc mừng! Hoàn tất món ăn".
//        - `prevStep()`: lùi 1 bước (nếu không phải bước đầu).
//        → Đổi bước mà đang bật giọng đọc thì TỰ ĐỌC bước mới.
//
//   3. GIỌNG ĐỌC — `toggleVoice()`:
//        - Bật  → đọc "Bước N trên M. (hướng dẫn). Mẹo: ..." ngay.
//                 Máy không đọc được tiếng Việt → tự tắt lại, trả về câu báo
//                 lỗi để UI hiện SnackBar.
//        - Tắt  → im ngay.
//
//   4. Thoát màn hình → `dispose()` tắt giọng đọc.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/models/recipe.dart';
import 'cooking_voice.dart';

class CookingModeController extends ChangeNotifier {
  CookingModeController({required this.recipe, CookingVoice? voice}) : _voice = voice ?? TtsCookingVoice();

  /// Báo lỗi khi máy không đọc được tiếng Việt.
  static const String voiceUnavailableMessage =
      'Máy chưa có giọng đọc tiếng Việt. Vào Cài đặt → Chuyển văn bản thành giọng nói '
      'để tải "Tiếng Việt" (Google Text-to-Speech).';

  final Recipe recipe;
  final CookingVoice _voice;

  int _currentStepIndex = 0;
  bool _isVoiceOn = false;
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  int get currentStepIndex => _currentStepIndex;
  InstructionStep get currentStep => recipe.instructions[_currentStepIndex];
  int get totalSteps => recipe.instructions.length;
  bool get isFirstStep => _currentStepIndex == 0;
  bool get isLastStep => _currentStepIndex == totalSteps - 1;

  /// Tiến độ 0.0 → 1.0 cho thanh progress.
  double get progress => totalSteps == 0 ? 0 : (_currentStepIndex + 1) / totalSteps;

  /// Đang bật giọng đọc (tự đọc mỗi khi sang bước).
  bool get isVoiceOn => _isVoiceOn;

  // ---------------------------------------------------------------------------
  // CHUYỂN BƯỚC
  // ---------------------------------------------------------------------------

  /// Sang bước tiếp theo. Trả về `false` nếu đã ở bước cuối (món đã hoàn tất).
  bool nextStep() {
    if (isLastStep) return false;

    _currentStepIndex++;
    notifyListeners();
    _readCurrentStepIfOn();
    return true;
  }

  void prevStep() {
    if (isFirstStep) return;

    _currentStepIndex--;
    notifyListeners();
    _readCurrentStepIfOn();
  }

  // ---------------------------------------------------------------------------
  // GIỌNG ĐỌC
  // ---------------------------------------------------------------------------

  /// Câu đọc cho bước hiện tại: `Bước 2 trên 5. (hướng dẫn). Mẹo: ...`.
  String get currentStepSpeech {
    final step = currentStep;
    final tip = step.tip;
    return [
      'Bước ${_currentStepIndex + 1} trên $totalSteps.',
      step.description,
      if (tip != null && tip.trim().isNotEmpty) 'Mẹo: $tip',
    ].join(' ');
  }

  /// Bật/tắt giọng đọc. Bật thì đọc bước hiện tại ngay.
  /// Trả về câu báo lỗi cho UI (null = ổn).
  Future<String?> toggleVoice() async {
    if (_isVoiceOn) {
      _isVoiceOn = false;
      notifyListeners();
      await _voice.stop();
      return null;
    }

    _isVoiceOn = true;
    notifyListeners();
    final ok = await _voice.speak(currentStepSpeech);
    if (ok || _disposed) return null;
    _isVoiceOn = false;
    notifyListeners();
    return voiceUnavailableMessage;
  }

  void _readCurrentStepIfOn() {
    if (_isVoiceOn) _voice.speak(currentStepSpeech);
  }

  @override
  void dispose() {
    _disposed = true;
    _voice.stop();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
