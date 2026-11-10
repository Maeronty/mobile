// =============================================================================
// WIDGET: Ô NHẬP MẬT KHẨU (có nút ẩn/hiện)
// =============================================================================
//
// FLOW
//   Bấm biểu tượng con mắt → đổi `_obscure` → hiện/ẩn mật khẩu.
//   Trạng thái ẩn/hiện chỉ thuộc về ô này nên giữ trong State của widget.
// =============================================================================

import 'package:flutter/material.dart';

class AuthPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;

  const AuthPasswordField({
    super.key,
    required this.controller,
    this.label = 'Mật khẩu',
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      onChanged: widget.onChanged,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
