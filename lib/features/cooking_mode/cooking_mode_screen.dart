// =============================================================================
// MÀN HÌNH: CHẾ ĐỘ NẤU ĂN TOÀN MÀN HÌNH (Cooking Mode)
// =============================================================================
//
// FILE NÀY CHỈ GHÉP CÁC KHU VỰC GIAO DIỆN; từng khu vực nằm trong `widgets/`.
// Logic chuyển bước và giọng đọc nằm trong `cooking_mode_controller.dart`.
//
// FLOW UI
//   1. initState → tạo CookingModeController rồi lắng nghe.
//   2. Nút loa (AppBar) → `_toggleVoiceReading` → controller bật/tắt giọng đọc
//      (bật thì đọc bước hiện tại, sang bước nào tự đọc bước đó). Máy không
//      có giọng tiếng Việt → SnackBar hướng dẫn cài.
//   3. "Bước trước" → prevStep;  "Bước tiếp" → `_nextStep`: nếu đã ở bước cuối
//      thì hiện dialog chúc mừng → đóng dialog + thoát Cooking Mode.
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/models/recipe.dart';
import '../../core/theme/app_colors.dart';
import 'cooking_mode_controller.dart';
import 'widgets/cooking_completion_dialog.dart';
import 'widgets/cooking_navigation_controls.dart';
import 'widgets/cooking_progress_header.dart';
import 'widgets/cooking_step_card.dart';

class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;

  const CookingModeScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  late final CookingModeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CookingModeController(recipe: widget.recipe);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  /// Bật/tắt giọng đọc; máy không đọc được tiếng Việt → báo cách cài.
  Future<void> _toggleVoiceReading() async {
    final error = await _controller.toggleVoice();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), duration: const Duration(seconds: 6)),
      );
    }
  }

  /// Sang bước tiếp; nếu đã là bước cuối thì chúc mừng hoàn tất.
  void _nextStep() {
    final moved = _controller.nextStep();
    if (!moved) _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => CookingCompletionDialog(recipeTitle: widget.recipe.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepNumber = _controller.currentStepIndex + 1;
    final totalSteps = _controller.totalSteps;

    if (totalSteps == 0) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.recipe.title)),
        body: const Center(child: Text('Công thức này chưa có các bước thực hiện.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark focused background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          widget.recipe.title,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _controller.isVoiceOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _controller.isVoiceOn ? AppColors.primary : Colors.white,
            ),
            tooltip: _controller.isVoiceOn ? 'Tắt giọng đọc' : 'Đọc hướng dẫn',
            onPressed: _toggleVoiceReading,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            CookingProgressHeader(
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              progress: _controller.progress,
            ),

            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CookingStepCard(
                  stepNumber: stepNumber,
                  step: _controller.currentStep,
                ),
              ),
            ),

            const SizedBox(height: 16),

            CookingNavigationControls(
              showPrevious: _controller.currentStepIndex > 0,
              isLastStep: _controller.currentStepIndex == totalSteps - 1,
              onPrevious: _controller.prevStep,
              onNext: _nextStep,
            ),
          ],
        ),
      ),
    );
  }
}
