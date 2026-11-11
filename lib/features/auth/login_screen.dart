// =============================================================================
// MÀN HÌNH: ĐĂNG NHẬP
// =============================================================================
//
// FILE NÀY CHỈ LÀ GIAO DIỆN; logic nằm trong `auth_controller.dart`.
//
// FLOW UI
//   1. Nhập email/tên đăng nhập + mật khẩu, chọn "Ghi nhớ đăng nhập".
//   2. Bấm "Đăng nhập" → Form kiểm tra ô rỗng → `AuthController.login`.
//      Thành công → AuthGate (app.dart) tự chuyển vào app, màn này không cần
//      điều hướng. Thất bại → hiện AuthErrorBanner với câu lỗi từ server.
//   3. "Đăng ký ngay" → mở RegisterScreen.
//   4. "Dùng thử không cần tài khoản" → `continueAsGuest()`.
// =============================================================================

import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'register_screen.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_password_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthController.instance;
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await _auth.login(
      usernameOrEmail: _identifierController.text,
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );
  }

  void _openRegister() {
    _auth.clearError();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListenableBuilder(
                listenable: _auth,
                builder: (context, _) => Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthHeader(
                          title: 'Chào mừng trở lại',
                          subtitle: 'Đăng nhập để lưu món yêu thích và nhận diện nguyên liệu từ ảnh.',
                        ),
                        const SizedBox(height: 28),
                        if (_auth.errorMessage != null) ...[
                          AuthErrorBanner(message: _auth.errorMessage!),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _identifierController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          onChanged: (_) => _auth.clearError(),
                          validator: (v) => AuthController.validateRequired(
                            v,
                            'email hoặc tên đăng nhập',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Email hoặc tên đăng nhập',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AuthPasswordField(
                          controller: _passwordController,
                          onChanged: (_) => _auth.clearError(),
                          validator: (v) =>
                              AuthController.validateRequired(v, 'mật khẩu'),
                          onSubmitted: _submit,
                        ),
                        CheckboxListTile(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? true),
                          title: const Text('Ghi nhớ đăng nhập'),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _auth.isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: _auth.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Đăng nhập',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Chưa có tài khoản?'),
                            TextButton(
                              onPressed: _auth.isLoading ? null : _openRegister,
                              child: const Text('Đăng ký ngay'),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        OutlinedButton.icon(
                          onPressed: _auth.isLoading
                              ? null
                              : _auth.continueAsGuest,
                          icon: const Icon(Icons.explore_outlined),
                          label: const Text('Dùng thử không cần tài khoản'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
