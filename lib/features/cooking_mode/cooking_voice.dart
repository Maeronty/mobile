// =============================================================================
// GIỌNG ĐỌC HƯỚNG DẪN NẤU (Text-to-Speech) — Cooking Mode
// =============================================================================
//
// VAI TRÒ
//   Bọc `flutter_tts` (bộ đọc văn bản có sẵn của Android/iOS) để controller
//   chỉ cần gọi `speak` / `stop`. Test thay bằng bản giả cùng interface.
//
// FLOW (`TtsCookingVoice`)
//   1. Lần `speak` đầu tiên → `_init()` MỘT lần:
//        - Máy có giọng tiếng Việt ("vi-VN") → dùng; không có → `speak` trả
//          false để UI báo cài giọng đọc tiếng Việt.
//        - Tốc độ đọc chậm vừa (0.45) cho dễ nghe khi đang nấu.
//   2. `speak(text)`: dừng câu đang đọc (nếu có) rồi đọc câu mới → chuyển
//      bước liên tục không bị đọc chồng.
//   3. `stop()`: im ngay. Lỗi nền tảng nào cũng bị nuốt, trả false — giọng đọc
//      là tiện ích, không được làm hỏng màn nấu.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract class CookingVoice {
  /// Đọc to `text`. Trả về false nếu máy không đọc được tiếng Việt / lỗi.
  Future<bool> speak(String text);

  Future<void> stop();
}

class TtsCookingVoice implements CookingVoice {
  static const String language = 'vi-VN';
  static const double speechRate = 0.45;

  final FlutterTts _tts = FlutterTts();
  Future<bool>? _ready;

  Future<bool> _init() async {
    try {
      final available = await _tts.isLanguageAvailable(language);
      if (available != true && available != 1) return false;
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(speechRate);
      await _tts.awaitSpeakCompletion(false);
      return true;
    } catch (e) {
      debugPrint('TtsCookingVoice: không khởi tạo được TTS: $e');
      return false;
    }
  }

  @override
  Future<bool> speak(String text) async {
    final ready = await (_ready ??= _init());
    if (!ready) return false;
    try {
      await _tts.stop();
      final result = await _tts.speak(text);
      return result == 1 || result == true;
    } catch (e) {
      debugPrint('TtsCookingVoice: lỗi khi đọc: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
