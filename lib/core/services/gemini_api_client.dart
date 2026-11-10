import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Shared Google Gemini REST client with multi-key rotation and 429 cooldowns.
class GeminiApiClient {
  final http.Client _client;
  final List<String> _apiKeys;
  final String _model;
  final String _baseUrl;
  final bool _ownsClient;
  final Map<String, DateTime> _keyCooldowns = {};

  GeminiApiClient({
    http.Client? client,
    String? apiKey,
    List<String>? apiKeys,
    String? model,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _apiKeys = resolveApiKeys(apiKey: apiKey, apiKeys: apiKeys),
        _model = resolveModel(model),
        _baseUrl = resolveBaseUrl(baseUrl),
        _ownsClient = client == null;

  bool get hasApiKeys => _apiKeys.isNotEmpty;
  String get model => _model;

  static List<String> resolveApiKeys({String? apiKey, List<String>? apiKeys}) {
    final Iterable<String> raw;
    if (apiKeys != null) {
      raw = apiKeys;
    } else if (apiKey != null) {
      raw = apiKey.split(',');
    } else {
      const envKeys = String.fromEnvironment('GEMINI_API_KEYS');
      const envKey = String.fromEnvironment('GEMINI_API_KEY');
      raw = [
        ...envKeys.split(','),
        ...envKey.split(','),
      ];
    }
    return raw.map((k) => k.trim()).where((k) => k.isNotEmpty).toSet().toList();
  }

  static String resolveModel(String? model) {
    final trimmed = model?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    const envModel = String.fromEnvironment('GEMINI_MODEL');
    return envModel.trim().isNotEmpty ? envModel.trim() : 'gemini-3.8-flash';
  }

  static String resolveBaseUrl(String? baseUrl) {
    final trimmed = baseUrl?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    const envBase = String.fromEnvironment(
      'GEMINI_BASE_URL',
      defaultValue: 'https://generativelanguage.googleapis.com/v1beta',
    );
    return envBase;
  }

  /// Sends a `generateContent` request expecting JSON text in return.
  Future<String> generateJsonText({
    required List<Map<String, dynamic>> parts,
    Map<String, dynamic>? responseSchema,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (_apiKeys.isEmpty) {
      throw const HttpException(
          'Chưa cấu hình GEMINI_API_KEY. Vui lòng cung cấp khóa API.');
    }

    final url = Uri.parse('$_baseUrl/models/$_model:generateContent');
    final generationConfig = <String, dynamic>{
      'responseMimeType': 'application/json',
      'responseSchema': ?responseSchema,
    };

    final payload = jsonEncode({
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': generationConfig,
    });

    final response = await _postWithKeyRotation(url, payload, timeout);
    if (response.statusCode != 200) {
      _handleHttpError(response.statusCode, response.body);
    }

    final Map<String, dynamic> body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const FormatException('Gemini không trả về kết quả nào.');
    }

    final responseParts = candidates[0]['content']?['parts'] as List?;
    if (responseParts == null || responseParts.isEmpty) {
      throw const FormatException('Nội dung phản hồi từ Gemini trống.');
    }

    final rawJsonText = responseParts
        .where((p) => p is Map && p['thought'] != true)
        .map((p) => (p as Map)['text'] as String? ?? '')
        .join()
        .trim();

    if (rawJsonText.isEmpty) {
      throw const FormatException('Nội dung phản hồi từ Gemini trống.');
    }

    return stripMarkdownCodeFence(rawJsonText);
  }

  /// Strips ```json / ``` fences if the model wrapped its JSON output.
  static String stripMarkdownCodeFence(String raw) {
    var clean = raw.trim();
    if (clean.startsWith('```json')) clean = clean.substring(7);
    if (clean.startsWith('```')) clean = clean.substring(3);
    if (clean.endsWith('```')) clean = clean.substring(0, clean.length - 3);
    return clean.trim();
  }

  Future<http.Response> _postWithKeyRotation(
    Uri url,
    String payload,
    Duration timeout,
  ) async {
    http.Response? last429Response;
    final now = DateTime.now();

    for (final key in _apiKeys) {
      final cooldownUntil = _keyCooldowns[key];
      if (cooldownUntil != null && cooldownUntil.isAfter(now)) {
        continue;
      }

      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': key,
            },
            body: payload,
          )
          .timeout(timeout);

      if (response.statusCode != 429) {
        return response;
      }

      _keyCooldowns[key] =
          DateTime.now().add(_retryDelayFromHeaders(response.headers));
      last429Response = response;
    }

    if (last429Response != null) {
      return last429Response;
    }

    throw const HttpException(
        'Các khóa Gemini đều đang bị giới hạn (429). Vui lòng thử lại sau.');
  }

  Duration _retryDelayFromHeaders(Map<String, String> headers) {
    final retryAfter = headers['retry-after']?.trim();
    if (retryAfter != null && retryAfter.isNotEmpty) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null && seconds > 0) {
        return Duration(seconds: seconds);
      }
      try {
        final diff = HttpDate.parse(retryAfter).difference(DateTime.now());
        if (!diff.isNegative && diff.inSeconds > 0) return diff;
      } catch (_) {}
    }
    return const Duration(seconds: 60);
  }

  Never _handleHttpError(int statusCode, String body) {
    String? detail;
    try {
      final err = jsonDecode(body);
      detail = err['error']?['message'] as String?;
    } catch (_) {}

    if (statusCode == 429) {
      throw HttpException(detail != null
          ? 'Lỗi 429: $detail'
          : 'Gemini API vượt quá giới hạn lượt gọi hoặc hết hạn mức (429).');
    } else if (statusCode == 401 || statusCode == 403) {
      throw HttpException(detail != null
          ? 'Lỗi $statusCode: $detail'
          : 'Khóa API Gemini không hợp lệ hoặc không có quyền truy cập ($statusCode).');
    } else if (statusCode >= 500) {
      throw HttpException(detail != null
          ? 'Lỗi $statusCode: $detail'
          : 'Máy chủ Gemini đang gặp sự cố ($statusCode). Vui lòng thử lại sau.');
    }
    throw HttpException(detail != null
        ? 'Lỗi $statusCode: $detail'
        : 'Yêu cầu tới Gemini thất bại với mã lỗi HTTP $statusCode.');
  }

  static String resolveErrorMessage(
    dynamic error, {
    String timeoutMessage =
        'Yêu cầu từ Gemini đã hết thời gian chờ. Vui lòng thử lại.',
    String fallbackMessage =
        'Đã xảy ra lỗi khi gọi Gemini. Vui lòng thử lại sau.',
  }) {
    if (error is SocketException || error is http.ClientException) {
      return 'Không thể kết nối đến Gemini. Vui lòng kiểm tra kết nối mạng.';
    }
    if (error is TimeoutException) {
      return timeoutMessage;
    }
    if (error is HttpException) {
      return error.message;
    }
    if (error is FormatException) {
      return error.message;
    }
    return fallbackMessage;
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
