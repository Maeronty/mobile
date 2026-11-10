// =============================================================================
// MÀN HÌNH: ĐĂNG KÝ TÀI KHOẢN
// =============================================================================
//
// FILE NÀY CHỈ LÀ GIAO DIỆN; logic và quy tắc kiểm tra nằm trong
// `auth_controller.dart`.
//
// FLOW UI
//   1. Nhập tên hiển thị, email, tên đăng nhập (không bắt buộc), mật khẩu,
//      nhập lại mật khẩu.
//   2. Bấm "Tạo tài khoản" → Form kiểm tra từng ô (email, độ mạnh mật khẩu
//      theo quy tắc của BE, hai mật khẩu khớp nhau) → `AuthController.register`.
//   3. Thành công → BE trả token, người dùng đã đăng nhập → đóng màn này;
//      AuthGate tự chuyển vào app. Thất bại (VD: email đã dùng) → banner lỗi.
// =============================================================================

import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_password_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = AuthController.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _emailController,
      _usernameController,
      _passwordController,
      _confirmController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await _auth.register(
      displayName: _nameController.text,
      email: _emailController.text,
      username: _usernameController.text,
      password: _passwordController.text,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) => _auth.clearError(),
      child: Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ListenableBuilder(
                  listenable: _auth,
                  builder: (context, _) => Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AuthHeader(
                            title: 'Tạo tài khoản mới',
                            subtitle: 'Miễn phí, chỉ mất vài giây.',
                          ),
                          const SizedBox(height: 28),
                          if (_auth.errorMessage != null) ...[
                            AuthErrorBanner(message: _auth.errorMessage!),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            validator: (v) => AuthController.validateRequired(
                              v,
                              'tên hiển thị',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Tên hiển thị',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            onChanged: (_) => _auth.clearError(),
                            validator: AuthController.validateEmail,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newUsername],
                            onChanged: (_) => _auth.clearError(),
                            decoration: const InputDecoration(
                              labelText: 'Tên đăng nhập (không bắt buộc)',
                              helperText:
                                  'Bỏ trống thì hệ thống tự tạo từ email',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AuthPasswordField(
                            controller: _passwordController,
                            textInputAction: TextInputAction.next,
                            validator: AuthController.validatePassword,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                            child: Text(
                              'Tối thiểu 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 14),
                          AuthPasswordField(
                            controller: _confirmController,
                            label: 'Nhập lại mật khẩu',
                            validator: (v) => v != _passwordController.text
                                ? 'Mật khẩu nhập lại không khớp'
                                : null,
                            onSubmitted: _submit,
                          ),
                          const SizedBox(height: 24),
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
                                    'Tạo tài khoản',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('Đã có tài khoản?'),
                              TextButton(
                                onPressed: _auth.isLoading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Đăng nhập'),
                              ),
                            ],
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
      ),
    );
  }
}
