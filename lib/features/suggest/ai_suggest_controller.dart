// =============================================================================
// FEATURE: GỢI Ý MÓN BẰNG AI (Gemini + Spoonacular, qua backend Rust)
// =============================================================================
//
// VAI TRÒ
//   Giữ danh sách nguyên liệu đang nhập, kết quả gợi ý và trạng thái chờ.
//   AiSuggestScreen chỉ hiển thị và gọi các hàm ở đây.
//
// FLOW NHẬN DIỆN ẢNH (`analyzeImage`)
//   1. Ảnh > 3 MB → báo lỗi. Đoán loại ảnh từ byte đầu file (JPEG/PNG/WebP),
//      không tin đuôi file.
//   2. `POST /api/Ai/recognize` {mime, data(base64)} → danh sách tên nguyên liệu.
//   3. Gộp với nguyên liệu đang nhập (bỏ trùng, không phân biệt hoa thường),
//      xoá kết quả cũ, báo người dùng kiểm tra lại trước khi tìm món.
//
// FLOW GỢI Ý MÓN (`suggest`)
//   1. Tách ô nhập theo dấu phẩy / chấm phẩy / xuống dòng, bỏ trùng.
//   2. `POST /api/Ai/suggest` {ingredients} → [{id, title, reason, used, missing}].
//   3. Rỗng → báo đổi nguyên liệu.
//
// LƯU Ý
//   - Cả hai API cần đăng nhập (tốn lượt gọi Gemini/Spoonacular): khách thì
//     `requiresLogin = true`, UI hiện nút đăng nhập thay vì gọi API.
//   - Lỗi nào cũng chuyển thành `message` để hiển thị, không ném ra UI.
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/data/api_client.dart';
import '../auth/auth_controller.dart';

/// Một món gợi ý trả về từ `/api/Ai/suggest` (đã dịch tiếng Việt).
class AiSuggestion {
  final int id;
  final String title;
  final String reason;
  final List<String> used;
  final List<String> missing;

  const AiSuggestion({
    required this.id,
    required this.title,
    required this.reason,
    required this.used,
    required this.missing,
  });

  factory AiSuggestion.fromJson(Map<String, dynamic> json) => AiSuggestion(
        id: json['id'] as int,
        title: json['title'] as String,
        reason: json['reason'] as String,
        used: [for (final x in json['used'] as List) x as String],
        missing: [for (final x in json['missing'] as List) x as String],
      );
}

class AiSuggestController extends ChangeNotifier {
  static const int maxImageBytes = 3 * 1024 * 1024;
  static const Duration aiTimeout = Duration(seconds: 150);

  AiSuggestController({List<String> initialIngredients = const [], ApiClient? api})
      : _api = api ?? ApiClient.instance,
        _input = initialIngredients.join(', ');

  final ApiClient _api;
  String _input;
  List<AiSuggestion> _results = [];
  String? _message;
  bool _busy = false;

  String get input => _input;
  List<AiSuggestion> get results => _results;
  String? get message => _message;
  bool get busy => _busy;
  bool get requiresLogin => !AuthController.instance.isLoggedIn;

  List<String> get ingredients => _input
      .split(RegExp('[,;\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  /// Người dùng sửa ô nhập → kết quả cũ không còn đúng nữa.
  void setInput(String value) {
    _input = value;
    _results = [];
    _message = null;
    notifyListeners();
  }

  /// Đoán loại ảnh từ byte đầu file; null nếu không phải JPEG/PNG/WebP.
  static String? detectMime(Uint8List bytes) {
    if (bytes.length < 12) return null;
    if (bytes[0] == 0xff && bytes[1] == 0xd8) return 'image/jpeg';
    if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
    if (ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') return 'image/webp';
    return null;
  }

  Future<void> analyzeImage(Uint8List bytes) => _run(() async {
        if (bytes.length > maxImageBytes) throw const ApiException('Hãy chọn ảnh nhỏ hơn 3 MB.');
        final mime = detectMime(bytes);
        if (mime == null) throw const ApiException('Hãy chọn ảnh JPG, PNG hoặc WebP.');

        final data = await _api.post('/api/Ai/recognize', {'mime': mime, 'data': base64Encode(bytes)},
            timeout: aiTimeout);
        final found = [for (final x in data as List) x as String];
        if (found.isEmpty) {
          _message = 'Gemini chưa nhận ra nguyên liệu. Hãy chụp gần hơn hoặc nhập tên.';
          return;
        }
        final combined = {for (final name in [...ingredients, ...found]) name.toLowerCase(): name};
        _input = combined.values.join(', ');
        _results = [];
        _message = 'Gemini nhận diện: ${found.join(', ')}. Bạn có thể sửa trước khi tìm món.';
      });

  Future<void> suggest() => _run(() async {
        final terms = ingredients;
        if (terms.isEmpty) throw const ApiException('Hãy thêm ít nhất một nguyên liệu.');
        _results = [];
        final data = await _api.post('/api/Ai/suggest', {'ingredients': terms}, timeout: aiTimeout);
        _results = [for (final x in data as List) AiSuggestion.fromJson(x as Map<String, dynamic>)];
        if (_results.isEmpty) _message = 'Chưa tìm thấy món phù hợp. Hãy đổi danh sách nguyên liệu.';
      });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    if (requiresLogin) {
      _message = 'Hãy đăng nhập để dùng gợi ý bằng AI.';
      notifyListeners();
      return;
    }
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (e) {
      _message = e.statusCode == 401 ? 'Phiên đăng nhập đã hết hạn, hãy đăng nhập lại.' : e.message;
    } catch (e) {
      debugPrint('AiSuggestController: $e');
      _message = 'Không thể hoàn tất. Vui lòng thử lại.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
