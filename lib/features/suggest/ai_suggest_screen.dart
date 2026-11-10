import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/data/recipe_repository.dart';
import '../../core/theme/app_colors.dart';
import '../kitchen_bag/pantry_controller.dart';
import '../recipe_detail/recipe_detail_screen.dart';
import 'ingredient_camera_scanner_screen.dart';
import 'ingredient_vision_service.dart';

class AiSuggestScreen extends StatefulWidget {
  const AiSuggestScreen({
    super.key,
    required this.ingredients,
    this.initialRecipes,
    this.client,
    this.visionService,
    this.onScanWithCamera,
  });

  final List<String> ingredients;
  final List<Map<String, dynamic>>? initialRecipes;
  final http.Client? client;
  final IngredientVisionService? visionService;
  final Future<XFile?> Function()? onScanWithCamera;

  @override
  State<AiSuggestScreen> createState() => _AiSuggestScreenState();
}

class _AiSuggestScreenState extends State<AiSuggestScreen> {
  static const base = String.fromEnvironment(
    'FOOD_API_URL',
    defaultValue: 'http://127.0.0.1:8787',
  );
  final picker = ImagePicker();
  late final http.Client client;
  late final bool _ownsClient;
  late final IngredientVisionService _visionService;
  late final bool _ownsVision;
  late final input = TextEditingController(text: widget.ingredients.join(', '));
  List<Map<String, dynamic>> recipes = [];
  ScannedImage? _scannedImage;
  String? message;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.client == null;
    client = widget.client ?? http.Client();
    _ownsVision = widget.visionService == null;
    _visionService =
        widget.visionService ?? IngredientVisionService(httpClient: client);
    if (widget.initialRecipes != null) {
      recipes = List<Map<String, dynamic>>.from(widget.initialRecipes!);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      picker.retrieveLostData().then((lost) {
        if (mounted && lost.files?.isNotEmpty == true) {
          run(() => analyze(lost.files!.first));
        }
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    input.dispose();
    if (_ownsVision) {
      _visionService.dispose();
    }
    if (_ownsClient) {
      client.close();
    }
    super.dispose();
  }

  List<String> get ingredients => input.text
      .split(RegExp('[,;\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  Future<List<dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await client
        .post(
          Uri.parse('$base/$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 150));
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw FormatException(
        data is Map && data['error'] is String
            ? data['error']
            : 'Yêu cầu thất bại. Hãy thử lại.',
      );
    }
    return data as List;
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } on FormatException catch (e) {
      if (mounted) message = e.message;
    } catch (_) {
      if (mounted) {
        message =
            'Không thể hoàn tất. Kiểm tra kết nối mạng/máy chủ hoặc quyền truy cập camera, rồi thử lại.';
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> analyze(XFile file) async {
    final validated = await IngredientVisionService.validateAndRead(file);
    if (!mounted) return;
    setState(() {
      _scannedImage = validated;
      recipes = [];
    });

    final found = await _visionService.recognizeIngredients(validated);
    if (!mounted) return;
    if (found.isEmpty) {
      message =
          'Gemini chưa nhận ra nguyên liệu trong ảnh. Hãy chụp gần hơn hoặc nhập tên.';
      return;
    }
    final combined = {
      for (final name in [...ingredients, ...found]) name.toLowerCase(): name,
    };
    input.text = combined.values.join(', ');
    recipes = [];
    message =
        'Gemini nhận diện: ${found.join(', ')}. Bạn có thể chỉnh sửa trước khi tìm món.';
  }

  Future<void> _scanWithCamera() => run(() async {
        final XFile? file;
        if (widget.onScanWithCamera != null) {
          file = await widget.onScanWithCamera!();
        } else {
          file = await Navigator.push<XFile?>(
            context,
            MaterialPageRoute(
              builder: (_) => const IngredientCameraScannerScreen(),
            ),
          );
        }
        if (file != null && mounted) await analyze(file);
      });

  Future<void> _pickFromGallery() => run(() async {
        final file = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 82,
          requestFullMetadata: false,
        );
        if (file != null && mounted) await analyze(file);
      });

  void _removeIngredient(String name) {
    final updated = ingredients
        .where((item) => item.toLowerCase() != name.toLowerCase())
        .toList();
    setState(() {
      input.text = updated.join(', ');
      recipes = [];
      message = null;
    });
  }

  void _saveToPantry() {
    final items = ingredients;
    if (items.isEmpty) return;
    for (final item in items) {
      PantryController.instance.addIngredient(item);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${items.length} nguyên liệu vào Túi Thần Kỳ.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> suggest() => run(() async {
        final terms = ingredients;
        if (terms.isEmpty) {
          throw const FormatException('Hãy thêm ít nhất một nguyên liệu.');
        }
        recipes = [];
        final data = await post('suggest', {'ingredients': terms});
        if (!mounted) return;
        recipes = data.cast<Map<String, dynamic>>();
        if (recipes.isEmpty) {
          message =
              'Chưa tìm thấy món phù hợp. Hãy đổi danh sách nguyên liệu.';
        }
      });

  void _openRecipeDetail(Map<String, dynamic> suggestion) {
    final rawId = suggestion['id'];
    final int id =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final title = suggestion['title'] as String? ?? 'Món gợi ý';
    final reason = suggestion['reason'] as String?;
    final used =
        (suggestion['used'] as List?)?.map((e) => e.toString()).toList() ??
            <String>[];
    final missing =
        (suggestion['missing'] as List?)?.map((e) => e.toString()).toList() ??
            <String>[];

    var recipe = RecipeRepository.instance.findByIdOrNull(id);
    if (recipe == null) {
      recipe = RecipeRepository.instance.createCompatibleRecipe(
        id: id,
        title: title,
        description: reason != null && reason.isNotEmpty
            ? reason
            : 'Gợi ý từ Gemini dựa trên nguyên liệu của bạn.',
        used: used,
        missing: missing,
      );
      RecipeRepository.instance.addRecipe(recipe);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipeId: recipe!.id,
          recipe: recipe,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIngredients = ingredients;
    return Scaffold(
      appBar: AppBar(title: const Text('Gợi ý với Gemini')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: input,
            enabled: !busy,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Nguyên liệu đang có',
              helperText: 'Phân cách tên nguyên liệu bằng dấu phẩy',
            ),
            onChanged: (_) => setState(() {
              recipes = [];
              message = null;
            }),
          ),
          if (currentIngredients.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final item in currentIngredients)
                  InputChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(item),
                    onDeleted: busy ? null : () => _removeIngredient(item),
                  ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.kitchen_outlined, size: 16),
                  label: const Text('Lưu vào Tủ lạnh'),
                  onPressed: busy ? null : _saveToPantry,
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: busy ? null : _scanWithCamera,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Quét bằng Camera'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Chọn ảnh'),
              ),
            ],
          ),
          if (_scannedImage != null) ...[
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _scannedImage!.bytes,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, size: 40),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      tooltip: 'Xóa ảnh xem trước',
                      onPressed: busy
                          ? null
                          : () => setState(() => _scannedImage = null),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : suggest,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Gợi ý món từ nguyên liệu'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(message!),
            ),
          for (final recipe in recipes)
            Card(
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: InkWell(
                onTap: () => _openRecipeDetail(recipe),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recipe['title'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (recipe['reason'] != null &&
                                    (recipe['reason'] as String)
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    recipe['reason'] as String,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final entry in {
                        'used': 'Đã có',
                        'missing': 'Cần thêm',
                      }.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${entry.value}: ${(recipe[entry.key] as List?)?.isEmpty ?? true ? "Không có" : (recipe[entry.key] as List).join(", ")}',
                          ),
                        ),
                      Text(
                        'Nguồn: Spoonacular · #${recipe['id']}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openRecipeDetail(recipe),
                          icon: const Icon(Icons.restaurant_menu),
                          label: const Text('Xem chi tiết & Nấu ăn'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
