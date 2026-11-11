// =============================================================================
// FEATURE: NHẬN DIỆN NGUYÊN LIỆU TỪ ẢNH → TÌM MÓN TRONG KHO CÔNG THỨC
// =============================================================================
//
// VAI TRÒ
//   Giữ danh sách nguyên liệu đang nhập, kết quả gợi ý và trạng thái chờ.
//   AiSuggestScreen chỉ hiển thị và gọi các hàm ở đây.
//
// FLOW NHẬN DIỆN ẢNH (`analyzeImage`) — bước DUY NHẤT dùng AI (Gemini)
//   1. Ảnh > 3 MB → báo lỗi. Đoán loại ảnh từ byte đầu file (JPEG/PNG/WebP),
//      không tin đuôi file.
//   2. `POST /api/Ai/recognize` {mime, data(base64)} → tên nguyên liệu (tiếng Việt).
//   3. Gộp với nguyên liệu đang nhập (bỏ trùng, không phân biệt hoa thường).
//   4. TỰ ĐỘNG tìm món luôn bằng danh sách mới (bước dưới). Người dùng vẫn có
//      thể sửa ô nhập rồi bấm tìm lại.
//
// FLOW TÌM MÓN (`suggest`) — KHÔNG gọi AI / API key nào
//   1. Tách ô nhập theo dấu phẩy / chấm phẩy / xuống dòng, bỏ trùng.
//   2. `POST /api/suggest` {ingredients} → server so khớp với nguyên liệu của
//      ≈ 3.600 công thức trong database → [{id, title, reason, used, missing}],
//      món dùng được nhiều nguyên liệu nhất (rồi cần mua ít nhất) lên đầu.
//   3. Rỗng → báo đổi nguyên liệu.
//
// LƯU Ý
//   - Chỉ nhận diện ảnh cần đăng nhập (tốn lượt gọi Gemini): khách thì
//     `requiresLogin = true`, UI ẩn nút ảnh và hiện nút đăng nhập. Tìm món theo
//     nguyên liệu gõ tay thì ai cũng dùng được.
//   - Lỗi nào cũng chuyển thành `message` để hiển thị, không ném ra UI.
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/data/api_client.dart';
import '../auth/auth_controller.dart';

/// Một món gợi ý trả về từ `/api/suggest`; `id` là id công thức trong database
/// (mở được màn Chi tiết).
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
  static const Duration searchTimeout = Duration(seconds: 20);

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

  /// Ô nhập tách theo , ; xuống dòng — bỏ trùng KHÔNG phân biệt hoa thường
  /// ("trứng", "Trứng" → giữ cái đầu).
  List<String> get ingredients {
    final seen = <String>{};
    return [
      for (final e in _input.split(RegExp('[,;\n]')).map((e) => e.trim()))
        if (e.isNotEmpty && seen.add(e.toLowerCase())) e,
    ];
  }

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

  Future<void> analyzeImage(Uint8List bytes) => _run(needsLogin: true, () async {
        if (bytes.length > maxImageBytes) throw const ApiException('Hãy chọn ảnh nhỏ hơn 3 MB.');
        final mime = detectMime(bytes);
        if (mime == null) throw const ApiException('Hãy chọn ảnh JPG, PNG hoặc WebP.');

        final data = await _api.post('/api/Ai/recognize', {'mime': mime, 'data': base64Encode(bytes)},
            timeout: aiTimeout);
        final found = [for (final x in data as List) x as String];
        if (found.isEmpty) {
          _message = 'Chưa nhận ra nguyên liệu trong ảnh. Hãy chụp gần hơn hoặc nhập tên.';
          return;
        }
        final combined = {for (final name in [...ingredients, ...found]) name.toLowerCase(): name};
        _input = combined.values.join(', ');
        notifyListeners(); // ô nhập hiện ngay nguyên liệu vừa nhận ra

        await _search();
        final count = _results.isEmpty ? ' — chưa tìm thấy món phù hợp' : ' — tìm thấy ${_results.length} món phù hợp';
        _message = 'Nhận diện: ${found.join(', ')}$count. Sửa ô nhập rồi bấm tìm lại nếu cần.';
      });

  Future<void> suggest() => _run(_search);

  /// So khớp nguyên liệu với kho công thức trên server (không dùng AI).
  Future<void> _search() async {
    final terms = ingredients;
    if (terms.isEmpty) throw const ApiException('Hãy thêm ít nhất một nguyên liệu.');
    _results = [];
    final data = await _api.post('/api/suggest', {'ingredients': terms}, timeout: searchTimeout);
    _results = [for (final x in data as List) AiSuggestion.fromJson(x as Map<String, dynamic>)];
    if (_results.isEmpty) _message = 'Chưa tìm thấy món phù hợp. Hãy đổi danh sách nguyên liệu.';
  }

  Future<void> _run(Future<void> Function() action, {bool needsLogin = false}) async {
    if (_busy) return;
    if (needsLogin && requiresLogin) {
      _message = 'Hãy đăng nhập để nhận diện nguyên liệu từ ảnh.';
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
