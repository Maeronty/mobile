// =============================================================================
// FEATURE: ĐĂNG NHẬP / ĐĂNG KÝ (Auth)
// =============================================================================
//
// VAI TRÒ
//   Giữ phiên đăng nhập của cả app: người dùng hiện tại, token JWT, chế độ khách.
//   LoginScreen / RegisterScreen chỉ gọi các hàm ở đây và hiển thị kết quả.
//
// FLOW KHỞI ĐỘNG (`restoreSession`, gọi trong main)
//   1. Đọc token + user đã lưu (chỉ có khi lần trước chọn "Ghi nhớ đăng nhập").
//   2. Có → gắn token vào ApiClient, gọi `GET /api/Account/profile` để kiểm tra:
//        - 401 (token hết hạn / sai) → xoá phiên, về màn đăng nhập.
//        - Mất mạng → vẫn giữ phiên, để dùng offline; gọi API sau sẽ tự báo lỗi.
//   3. `isReady = true` → AuthGate chọn màn hình.
//
// FLOW ĐĂNG NHẬP (`login`)
//   1. Kiểm tra ô nhập rỗng (phía UI dùng các hàm validate* bên dưới).
//   2. `POST /api/Account/login` {usernameOrEmail, password, rememberMe}.
//   3. Thành công → lưu user + token (lưu xuống máy nếu rememberMe) →
//      notifyListeners → AuthGate chuyển sang MainNavigationScreen.
//   4. Lỗi → `errorMessage` = câu lỗi từ BE (VD: sai mật khẩu), UI hiển thị.
//
// FLOW ĐĂNG KÝ (`register`)
//   1. Kiểm tra email + mật khẩu theo ĐÚNG quy tắc của BE Rust
//      (`backend/src/services/auth_service.rs`), để báo lỗi ngay không cần gọi server.
//   2. `POST /api/Account/register` → BE trả token luôn → đăng nhập ngay,
//      phiên được ghi nhớ.
//
// KHÁCH & ĐĂNG XUẤT
//   - "Dùng thử không cần tài khoản" → `continueAsGuest()`: vào app nhưng
//     không có token; tính năng AI sẽ yêu cầu đăng nhập.
//   - `logout()` → xoá token trong ApiClient và trên máy → về màn đăng nhập.
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/api_client.dart';
import '../../core/models/auth_user.dart';
import '../favorites/favorites_controller.dart';

class AuthController extends ChangeNotifier {
  static const _tokenKey = 'auth.token';
  static const _userKey = 'auth.user';

  /// Singleton: phiên đăng nhập dùng chung toàn app.
  static final AuthController instance = AuthController(ApiClient.instance);

  AuthController(this._api);

  final ApiClient _api;

  AuthUser? _user;
  bool _isGuest = false;
  bool _isReady = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isGuest => _isGuest;
  bool get isReady => _isReady;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Đã đăng nhập hoặc chọn dùng thử → được vào app.
  bool get canEnterApp => isLoggedIn || _isGuest;

  // ---------------------------------------------------------------------------
  // Kiểm tra dữ liệu nhập (trả về câu lỗi, hoặc null nếu hợp lệ)
  // ---------------------------------------------------------------------------

  static String? validateRequired(String? value, String field) =>
      (value == null || value.trim().isEmpty) ? 'Vui lòng nhập $field' : null;

  /// Giống `validate_email` của BE: ≥ 5 ký tự, có '@' và '.'.
  static String? validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập email';
    if (v.length < 5 || !v.contains('@') || !v.contains('.')) {
      return 'Email không hợp lệ';
    }
    return null;
  }

  /// Giống `validate_password_complexity` của BE: ≥ 8 ký tự, có chữ thường,
  /// chữ hoa, số và ký tự đặc biệt.
  static String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
    if (!RegExp('[a-z]').hasMatch(v)) return 'Cần ít nhất 1 chữ thường';
    if (!RegExp('[A-Z]').hasMatch(v)) return 'Cần ít nhất 1 chữ hoa';
    if (!RegExp(r'\d').hasMatch(v)) return 'Cần ít nhất 1 chữ số';
    if (!RegExp(r'[^\da-zA-Z]').hasMatch(v)) {
      return 'Cần ít nhất 1 ký tự đặc biệt (!@#...)';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Flow chính
  // ---------------------------------------------------------------------------

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userJson = prefs.getString(_userKey);
      if (token != null && userJson != null) {
        _api.token = token;
        _user = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        FavoritesController.instance.syncWithServer();
        try {
          await _api.get(
            '/api/Account/profile',
            timeout: const Duration(seconds: 3),
          );
        } on ApiException catch (e) {
          if (e.statusCode == 401) await _clearSession();
        }
      }
    } catch (e) {
      debugPrint('AuthController.restoreSession: $e');
      await _clearSession();
    }
    _isReady = true;
    notifyListeners();
  }

  Future<bool> login({
    required String usernameOrEmail,
    required String password,
    bool rememberMe = true,
  }) {
    return _authenticate('/api/Account/login', {
      'usernameOrEmail': usernameOrEmail.trim(),
      'password': password,
      'rememberMe': rememberMe,
    }, remember: rememberMe);
  }

  Future<bool> register({
    required String displayName,
    required String email,
    required String password,
    String? username,
  }) {
    return _authenticate('/api/Account/register', {
      'displayName': displayName.trim(),
      'email': email.trim(),
      'password': password,
      if (username != null && username.trim().isNotEmpty)
        'username': username.trim(),
    }, remember: true);
  }

  void continueAsGuest() {
    _isGuest = true;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await _clearSession();
    _isGuest = false;
    notifyListeners();
  }

  /// Xoá thông báo lỗi khi người dùng sửa ô nhập hoặc đổi màn hình.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Nội bộ
  // ---------------------------------------------------------------------------

  Future<bool> _authenticate(
    String path,
    Map<String, dynamic> body, {
    required bool remember,
  }) async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.post(path, body) as Map<String, dynamic>;
      final token = data['token'] as String;
      _user = AuthUser.fromJson(data);
      _isGuest = false;
      _api.token = token;
      FavoritesController.instance.syncWithServer();
      if (remember) await _saveSession(token, _user!);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      debugPrint('AuthController: $e');
      _errorMessage = 'Máy chủ trả dữ liệu không hợp lệ.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSession(String token, AuthUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('AuthController: không lưu được phiên: $e');
    }
  }

  Future<void> _clearSession() async {
    _user = null;
    _api.token = null;
    FavoritesController.instance.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (_) {}
  }
}
