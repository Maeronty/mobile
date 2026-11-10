// Test AuthController với server giả (MockClient), dữ liệu theo đúng
// `AuthResponse` và định dạng lỗi `{message, error}` của backend Rust.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomato_food_tip/core/data/api_client.dart';
import 'package:tomato_food_tip/features/auth/auth_controller.dart';

http.Response jsonResponse(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

const authResponse = {
  'userId': 7,
  'username': 'an_nguyen',
  'email': 'an@example.com',
  'displayName': 'An Nguyễn',
  'avatarUrl': null,
  'role': 'User',
  'token': 'jwt-token',
};

ApiClient fakeApi(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(baseUrl: 'http://test', client: MockClient(handler));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('đăng nhập thành công: lưu user, gắn token, ghi nhớ phiên', () async {
    late http.Request sent;
    final api = fakeApi((r) async {
      sent = r;
      return jsonResponse(authResponse, 200);
    });
    final auth = AuthController(api);

    expect(await auth.login(usernameOrEmail: ' an@example.com ', password: 'Abc@1234'), isTrue);
    expect(sent.url.path, '/api/Account/login');
    expect(jsonDecode(sent.body), {'usernameOrEmail': 'an@example.com', 'password': 'Abc@1234', 'rememberMe': true});
    expect(auth.user!.displayName, 'An Nguyễn');
    expect(api.token, 'jwt-token');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth.token'), 'jwt-token');
  });

  test('sai mật khẩu: hiện câu lỗi của server, không đăng nhập', () async {
    const message = 'Email/tên đăng nhập hoặc mật khẩu không chính xác.';
    final api = fakeApi((_) async => jsonResponse({'message': message, 'error': message}, 401));
    final auth = AuthController(api);

    expect(await auth.login(usernameOrEmail: 'an', password: 'sai'), isFalse);
    expect(auth.errorMessage, message);
    expect(auth.isLoggedIn, isFalse);
    expect(api.token, isNull);
  });

  test('không ghi nhớ thì không lưu token xuống máy', () async {
    final api = fakeApi((_) async => jsonResponse(authResponse, 200));
    await AuthController(api).login(usernameOrEmail: 'an', password: 'Abc@1234', rememberMe: false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth.token'), isNull);
  });

  test('đăng ký gửi đúng trường và bỏ username rỗng', () async {
    late Map<String, dynamic> body;
    final api = fakeApi((r) async {
      expect(r.url.path, '/api/Account/register');
      body = jsonDecode(r.body) as Map<String, dynamic>;
      return jsonResponse(authResponse, 200);
    });
    final auth = AuthController(api);

    expect(
      await auth.register(displayName: ' An ', email: 'an@example.com', password: 'Abc@1234', username: ' '),
      isTrue,
    );
    expect(body, {'displayName': 'An', 'email': 'an@example.com', 'password': 'Abc@1234'});
    expect(auth.isLoggedIn, isTrue);
  });

  test('khôi phục phiên: token hết hạn (401) thì xoá phiên', () async {
    SharedPreferences.setMockInitialValues({'auth.token': 'old', 'auth.user': jsonEncode(authResponse)});
    final api = fakeApi((r) async {
      expect(r.headers['Authorization'], 'Bearer old');
      return jsonResponse({'message': 'Token hết hạn'}, 401);
    });
    final auth = AuthController(api);
    await auth.restoreSession();
    expect(auth.isReady, isTrue);
    expect(auth.isLoggedIn, isFalse);
    expect(api.token, isNull);
  });

  test('khôi phục phiên: mất mạng thì vẫn giữ đăng nhập', () async {
    SharedPreferences.setMockInitialValues({'auth.token': 'ok', 'auth.user': jsonEncode(authResponse)});
    final api = fakeApi((_) async => throw Exception('offline'));
    final auth = AuthController(api);
    await auth.restoreSession();
    expect(auth.isLoggedIn, isTrue);
    expect(api.token, 'ok');
  });

  test('quy tắc mật khẩu và email giống backend Rust', () {
    expect(AuthController.validatePassword('Abc@1234'), isNull);
    expect(AuthController.validatePassword('abc@1234'), 'Cần ít nhất 1 chữ hoa');
    expect(AuthController.validatePassword('Abcd1234'), 'Cần ít nhất 1 ký tự đặc biệt (!@#...)');
    expect(AuthController.validatePassword('Ab@1'), 'Mật khẩu tối thiểu 8 ký tự');
    expect(AuthController.validateEmail('a@b'), 'Email không hợp lệ');
  });
}
