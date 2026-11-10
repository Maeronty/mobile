import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';

/// Màn hình quét nguyên liệu bằng camera trực tiếp trong app.
/// Trả về [XFile] (từ camera hoặc thư viện ảnh) khi người dùng xác nhận quét.
class IngredientCameraScannerScreen extends StatefulWidget {
  final Future<List<CameraDescription>> Function()? loadCameras;
  final CameraController Function(CameraDescription camera)? controllerBuilder;
  final Future<XFile?> Function()? onPickFromGallery;

  const IngredientCameraScannerScreen({
    super.key,
    this.loadCameras,
    this.controllerBuilder,
    this.onPickFromGallery,
  });

  @override
  State<IngredientCameraScannerScreen> createState() =>
      _IngredientCameraScannerScreenState();
}

class _IngredientCameraScannerScreenState
    extends State<IngredientCameraScannerScreen> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();

  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  bool _flashOn = false;
  String? _errorMessage;

  XFile? _capturedFile;
  Uint8List? _capturedBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!isMobile || _cameras.isEmpty || _capturedFile != null) return;

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _startController(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _errorMessage = null;
    });

    try {
      final loader = widget.loadCameras ?? availableCameras;
      final cameras = await loader();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() {
          _cameras = [];
          _initializing = false;
          _errorMessage =
              'Không tìm thấy camera trên thiết bị. Bạn vẫn có thể chọn ảnh từ thư viện.';
        });
        return;
      }

      final backIndex = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _cameras = cameras;
      _selectedCameraIndex = backIndex >= 0 ? backIndex : 0;
      await _startController(_cameras[_selectedCameraIndex]);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = _mapCameraError(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage =
            'Không thể khởi động camera. Kiểm tra quyền truy cập camera hoặc chọn ảnh từ thư viện.';
      });
    }
  }

  Future<void> _startController(CameraDescription camera) async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final controller = widget.controllerBuilder?.call(camera) ??
        CameraController(
          camera,
          ResolutionPreset.high,
          enableAudio: false,
        );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _flashOn = false;
        _errorMessage = null;
      });
    } on CameraException catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = _mapCameraError(e);
      });
    }
  }

  String _mapCameraError(CameraException e) {
    final code = e.code.toLowerCase();
    if (code.contains('access') || code.contains('permission')) {
      return 'Ứng dụng chưa được cấp quyền Camera. Hãy cấp quyền trong Cài đặt hoặc chọn ảnh từ thư viện.';
    }
    return e.description?.isNotEmpty == true
        ? 'Không thể mở camera (${e.description}).'
        : 'Không thể mở camera trên thiết bị này.';
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _initializing || _capturing) return;
    setState(() => _initializing = true);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _startController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final nextMode = _flashOn ? FlashMode.off : FlashMode.torch;
    try {
      await controller.setFlashMode(nextMode);
      if (mounted) setState(() => _flashOn = !_flashOn);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera hiện tại không hỗ trợ đèn flash.')),
      );
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing ||
        _initializing) {
      return;
    }

    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _capturedFile = file;
        _capturedBytes = bytes;
        _capturing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể chụp ảnh. Vui lòng thử lại.')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    if (_capturing) return;
    try {
      final file = await (widget.onPickFromGallery?.call() ??
          _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1280,
            maxHeight: 1280,
            imageQuality: 82,
            requestFullMetadata: false,
          ));
      if (file != null && mounted) {
        Navigator.pop(context, file);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở thư viện ảnh.')),
      );
    }
  }

  void _retake() {
    setState(() {
      _capturedFile = null;
      _capturedBytes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _capturedFile != null && _capturedBytes != null
            ? _buildCapturedPreview()
            : _buildCameraBody(),
      ),
    );
  }

  Widget _buildCapturedPreview() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Xác nhận ảnh nguyên liệu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(
                _capturedBytes!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.image_outlined, color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Chụp lại'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _capturedFile),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Quét bằng Gemini'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraBody() {
    final controller = _controller;
    final hasPreview =
        !_initializing && controller != null && controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_initializing)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Đang mở camera...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          )
        else if (_errorMessage != null || !hasPreview)
          _buildUnavailableView()
        else
          Center(
            child: CameraPreview(controller),
          ),
        if (hasPreview) _buildScanFrameOverlay(),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleControlButton(
                icon: Icons.close,
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(context),
              ),
              if (hasPreview)
                Row(
                  children: [
                    _CircleControlButton(
                      icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                      tooltip: 'Đèn flash',
                      onPressed: _toggleFlash,
                    ),
                    if (_cameras.length > 1) ...[
                      const SizedBox(width: 8),
                      _CircleControlButton(
                        icon: Icons.cameraswitch_rounded,
                        tooltip: 'Đổi camera',
                        onPressed: _switchCamera,
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
        if (hasPreview)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Đưa nguyên liệu vào khung để Gemini nhận diện',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CircleControlButton(
                      icon: Icons.photo_library_rounded,
                      tooltip: 'Chọn từ thư viện',
                      onPressed: _pickFromGallery,
                    ),
                    GestureDetector(
                      onTap: _capturing ? null : _capturePhoto,
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: Colors.white24,
                        ),
                        child: Center(
                          child: _capturing
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : Container(
                                  width: 58,
                                  height: 58,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildScanFrameOverlay() {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.72,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.85),
                  width: 2.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailableView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_rounded,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Camera không khả dụng.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _initCamera,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại mở camera'),
                ),
                FilledButton.icon(
                  onPressed: _pickFromGallery,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Chọn ảnh từ thư viện'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _CircleControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
