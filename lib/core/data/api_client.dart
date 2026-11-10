// =============================================================================
// API CLIENT — Gọi REST API của backend Rust (thư mục `backend/`)
// =============================================================================
//
// VAI TRÒ
//   Nơi DUY NHẤT trong app biết địa chỉ server, gắn token đăng nhập và đọc lỗi.
//   Controller chỉ gọi `get` / `post` rồi tự chuyển JSON thành model.
//
// FLOW MỘT REQUEST
//   1. Ghép `baseUrl` + đường dẫn (VD: `/api/Account/login`).
//   2. Có token (đã đăng nhập) → thêm header `Authorization: Bearer <token>`.
//   3. Mã 2xx → giải mã JSON (UTF-8) và trả về.
//   4. Mã khác → đọc trường `message` (BE Rust luôn trả `message` + `error`)
//      → ném [ApiException]. Mất mạng / hết giờ / JSON hỏng cũng thành
//      [ApiException], nơi gọi chỉ cần bắt một loại lỗi.
//
// ĐỊA CHỈ SERVER
//   Mặc định: Android emulator → `http://10.0.2.2:8787`, nơi khác → `127.0.0.1:8787`.
//   Máy/điện thoại khác: `flutter run --dart-define=FOOD_API_URL=http://<ip>:8787`.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Lỗi khi gọi API; [message] là câu tiếng Việt hiển thị được cho người dùng.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  static const String _definedBaseUrl = String.fromEnvironment('FOOD_API_URL');

  /// Singleton dùng chung cho cả app.
  static final ApiClient instance = ApiClient();

  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? defaultBaseUrl();

  final http.Client _client;
  final String baseUrl;

  /// Token JWT hiện tại; AuthController đặt khi đăng nhập, xoá khi đăng xuất.
  String? token;

  static String defaultBaseUrl() {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:8787' : 'http://127.0.0.1:8787';
  }

  Future<dynamic> get(String path, {Duration timeout = const Duration(seconds: 20)}) {
    return _send(() => _client.get(_uri(path), headers: _headers()), timeout);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) {
    return _send(
      () => _client.post(_uri(path), headers: _headers(json: true), body: jsonEncode(body)),
      timeout,
    );
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers({bool json = false}) => {
        if (json) 'Content-Type': 'application/json; charset=utf-8',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(Future<http.Response> Function() request, Duration timeout) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException('Máy chủ phản hồi quá lâu. Vui lòng thử lại.');
    } catch (_) {
      throw const ApiException('Không kết nối được tới máy chủ. Kiểm tra backend đã chạy chưa.');
    }

    dynamic data;
    try {
      data = response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      data = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final message = data is Map && data['message'] is String
        ? data['message'] as String
        : 'Yêu cầu thất bại (mã ${response.statusCode}).';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
