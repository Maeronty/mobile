// =============================================================================
// MÀN HÌNH: NHẬN DIỆN NGUYÊN LIỆU TỪ ẢNH & TÌM MÓN
// =============================================================================
//
// FILE NÀY CHỈ LÀ GIAO DIỆN; logic nằm trong `ai_suggest_controller.dart`.
//
// FLOW UI
//   1. Mở từ màn Gợi ý (chế độ "Theo Nguyên Liệu" → nút "Gemini"), nhận sẵn
//      nguyên liệu đang chọn.
//   2. Khách → ẩn nút ảnh, hiện thẻ "Đăng nhập để nhận diện ảnh"; bấm → đóng
//      các màn đang mở và về LoginScreen. Tìm món theo tên gõ tay vẫn dùng được.
//   3. Chụp / chọn ảnh → `controller.analyzeImage` → ô nhập được cập nhật theo
//      nguyên liệu nhận ra VÀ danh sách món hiện ngay (tìm trong kho công thức).
//   4. Sửa ô nhập → bấm "Tìm món từ nguyên liệu" → `controller.suggest`.
//   5. Mỗi món: đã có / cần thêm; chạm "Xem công thức" → màn Chi tiết.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/auth_controller.dart';
import '../recipe_detail/recipe_detail_screen.dart';
import 'ai_suggest_controller.dart';

class AiSuggestScreen extends StatefulWidget {
  const AiSuggestScreen({super.key, required this.ingredients});
  final List<String> ingredients;

  @override
  State<AiSuggestScreen> createState() => _AiSuggestScreenState();
}

class _AiSuggestScreenState extends State<AiSuggestScreen> {
  final _picker = ImagePicker();
  late final _controller = AiSuggestController(initialIngredients: widget.ingredients);
  late final _input = TextEditingController(text: _controller.input);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncInput);
    // Android có thể huỷ app khi mở camera; lấy lại ảnh vừa chụp nếu có.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && !_controller.requiresLogin) {
      _picker.retrieveLostData().then((lost) async {
        final file = lost.files?.firstOrNull;
        if (file != null && mounted) await _controller.analyzeImage(await file.readAsBytes());
      });
    }
  }

  /// Controller đổi nguyên liệu (sau khi nhận diện ảnh) → cập nhật ô nhập.
  void _syncInput() {
    if (_input.text != _controller.input) _input.text = _controller.input;
  }

  @override
  void dispose() {
    _controller.removeListener(_syncInput);
    _controller.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (file != null && mounted) await _controller.analyzeImage(await file.readAsBytes());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được camera / thư viện ảnh. Kiểm tra quyền truy cập.')),
        );
      }
    }
  }

  void _goToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    AuthController.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    final camera = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      appBar: AppBar(title: const Text('Tìm món từ nguyên liệu')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final busy = _controller.busy;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_controller.requiresLogin)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Nhận diện từ ảnh cần đăng nhập'),
                    subtitle: const Text('Bạn vẫn có thể gõ tên nguyên liệu để tìm món.'),
                    trailing: FilledButton(onPressed: _goToLogin, child: const Text('Đăng nhập')),
                  ),
                ),
              TextField(
                controller: _input,
                enabled: !busy,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Nguyên liệu đang có',
                  helperText: 'Phân cách tên nguyên liệu bằng dấu phẩy',
                ),
                onChanged: _controller.setInput,
              ),
              const SizedBox(height: 16),
              if (!_controller.requiresLogin) ...[
                const Text(
                  'Ảnh chỉ được gửi đến Gemini để nhận diện nguyên liệu; món ăn được tìm trong kho công thức của app.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    if (camera)
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Chụp ảnh'),
                      ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Chọn ảnh'),
                    ),
                  ],
                ),
              ],
              FilledButton.icon(
                onPressed: busy ? null : _controller.suggest,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Tìm món từ nguyên liệu'),
              ),
              if (busy) const LinearProgressIndicator(),
              if (_controller.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_controller.message!),
                ),
              for (final recipe in _controller.results)
                Card(
                  child: ExpansionTile(
                    title: Text(recipe.title),
                    subtitle: Text(recipe.reason),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đã có: ${recipe.used.isEmpty ? "Không có" : recipe.used.join(", ")}'),
                      Text('Cần thêm: ${recipe.missing.isEmpty ? "Không có" : recipe.missing.join(", ")}'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipe.id)),
                          ),
                          icon: const Icon(Icons.menu_book_rounded),
                          label: const Text('Xem công thức'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
