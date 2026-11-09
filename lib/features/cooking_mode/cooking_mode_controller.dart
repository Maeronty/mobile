// =============================================================================
// FEATURE: CHẾ ĐỘ NẤU RẢNH TAY TỪNG BƯỚC (Step-by-Step Cooking Mode)
// =============================================================================
//
// VAI TRÒ
//   Điều khiển 1 phiên nấu ăn: bước hiện tại, đồng hồ đếm ngược cho từng bước
//   và trạng thái "trợ lý giọng nói" (mô phỏng).
//
// FLOW
//   1. Khởi tạo → đứng ở bước 0, gọi `_resetTimerForCurrentStep()`:
//        secondsLeft = (estimatedMinutes của bước, mặc định 3 phút) × 60,
//        timer dừng, tắt giọng nói.
//
//   2. ĐỒNG HỒ — `toggleTimer()`:
//        - Đang chạy  → huỷ Timer, chuyển sang tạm dừng.
//        - Đang dừng  → tạo Timer.periodic 1 giây:
//             mỗi tick: secondsLeft > 0 → giảm 1 → notify (UI cập nhật mm:ss)
//                       secondsLeft = 0 → huỷ Timer, dừng, gọi
//                       `onTimerFinished` để UI hiện dialog "Hết giờ!".
//        - `resetTimer()` (nút ↻): dừng và nạp lại thời gian của bước hiện tại.
//
//   3. CHUYỂN BƯỚC:
//        - `nextStep()`: chưa phải bước cuối → sang bước kế + reset timer,
//          trả về `true`. Đang ở bước cuối → trả về `false` để UI hiện dialog
//          "Chúc mừng! Hoàn tất món ăn".
//        - `prevStep()`: lùi 1 bước (nếu không phải bước đầu) + reset timer.
//        → Mỗi lần đổi bước đều reset timer theo thời gian của bước mới.
//
//   4. GIỌNG NÓI — `toggleVoice()`: bật/tắt cờ isVoiceSpeaking. Khi bật, UI hiện
//      SnackBar nội dung bước hiện tại (mô phỏng đọc to).
//
//   5. Thoát màn hình → `dispose()` huỷ Timer để không chạy ngầm.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/recipe.dart';

class CookingModeController extends ChangeNotifier {
  CookingModeController({required this.recipe, this.onTimerFinished}) {
    _resetTimerForCurrentStep();
  }

  /// Thời gian mặc định (phút) cho bước không khai báo `estimatedMinutes`.
  static const int defaultStepMinutes = 3;

  final Recipe recipe;

  /// Gọi khi đồng hồ của bước hiện tại đếm về 0.
  final VoidCallback? onTimerFinished;

  int _currentStepIndex = 0;
  Timer? _timer;
  int _secondsLeft = 0;
  bool _isTimerRunning = false;
  bool _isVoiceSpeaking = false;

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  int get currentStepIndex => _currentStepIndex;
  InstructionStep get currentStep => recipe.instructions[_currentStepIndex];
  int get totalSteps => recipe.instructions.length;
  bool get isFirstStep => _currentStepIndex == 0;
  bool get isLastStep => _currentStepIndex == totalSteps - 1;

  /// Tiến độ 0.0 → 1.0 cho thanh progress.
  double get progress => (_currentStepIndex + 1) / totalSteps;

  int get secondsLeft => _secondsLeft;
  bool get isTimerRunning => _isTimerRunning;
  bool get isVoiceSpeaking => _isVoiceSpeaking;

  /// Thời gian còn lại dạng "mm:ss".
  String get formattedTime => formatTime(_secondsLeft);

  static String formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // ĐỒNG HỒ
  // ---------------------------------------------------------------------------

  void toggleTimer() {
    if (_isTimerRunning) {
      _timer?.cancel();
      _isTimerRunning = false;
      notifyListeners();
      return;
    }

    _isTimerRunning = true;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    if (_secondsLeft > 0) {
      _secondsLeft--;
      notifyListeners();
      return;
    }

    // Hết giờ.
    _timer?.cancel();
    _isTimerRunning = false;
    notifyListeners();
    onTimerFinished?.call();
  }

  /// Nút ↻ trên UI: dừng đồng hồ và nạp lại thời gian của bước hiện tại.
  void resetTimer() {
    _resetTimerForCurrentStep();
    notifyListeners();
  }

  /// Dừng timer và nạp lại thời gian theo bước hiện tại.
  void _resetTimerForCurrentStep() {
    _timer?.cancel();
    _secondsLeft = (currentStep.estimatedMinutes ?? defaultStepMinutes) * 60;
    _isTimerRunning = false;
    _isVoiceSpeaking = false;
  }

  // ---------------------------------------------------------------------------
  // CHUYỂN BƯỚC
  // ---------------------------------------------------------------------------

  /// Sang bước tiếp theo. Trả về `false` nếu đã ở bước cuối (món đã hoàn tất).
  bool nextStep() {
    if (isLastStep) return false;

    _currentStepIndex++;
    _resetTimerForCurrentStep();
    notifyListeners();
    return true;
  }

  void prevStep() {
    if (isFirstStep) return;

    _currentStepIndex--;
    _resetTimerForCurrentStep();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GIỌNG NÓI (mô phỏng)
  // ---------------------------------------------------------------------------

  /// Bật/tắt đọc hướng dẫn. Trả về trạng thái mới (`true` = đang đọc).
  bool toggleVoice() {
    _isVoiceSpeaking = !_isVoiceSpeaking;
    notifyListeners();
    return _isVoiceSpeaking;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
