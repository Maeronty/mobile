// =============================================================================
// MÀN HÌNH: CHẾ ĐỘ NẤU ĂN TOÀN MÀN HÌNH (Cooking Mode)
// =============================================================================
//
// FILE NÀY CHỈ GHÉP CÁC KHU VỰC GIAO DIỆN; từng khu vực nằm trong `widgets/`.
// Logic chuyển bước, đồng hồ đếm ngược và giọng nói nằm trong
// `cooking_mode_controller.dart`.
//
// FLOW UI
//   1. initState → tạo CookingModeController, truyền callback
//      `_showTimerFinishedDialog` để hiện dialog khi hết giờ, rồi lắng nghe.
//   2. Nút loa (AppBar) → `_toggleVoiceReading` → khi bật hiện SnackBar
//      nội dung bước (mô phỏng trợ lý giọng nói).
//   3. Nút Play/Pause → controller.toggleTimer.
//   4. "Bước trước" → prevStep;  "Bước tiếp" → `_nextStep`: nếu đã ở bước cuối
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
import 'widgets/cooking_timer_finished_dialog.dart';
import 'widgets/cooking_timer_panel.dart';

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
    _controller = CookingModeController(
      recipe: widget.recipe,
      onTimerFinished: _showTimerFinishedDialog,
    );
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  void _showTimerFinishedDialog() {
    showDialog(
      context: context,
      builder: (context) => CookingTimerFinishedDialog(
        stepNumber: _controller.currentStepIndex + 1,
      ),
    );
  }

  /// Bật/tắt giọng nói; khi bật thì hiện nội dung bước hiện tại.
  void _toggleVoiceReading() {
    final isSpeaking = _controller.toggleVoice();
    if (isSpeaking) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang đọc hướng dẫn: ${_controller.currentStep.description}'),
          duration: const Duration(seconds: 3),
        ),
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
              _controller.isVoiceSpeaking ? Icons.volume_up_rounded : Icons.volume_down_rounded,
              color: _controller.isVoiceSpeaking ? AppColors.primary : Colors.white,
            ),
            tooltip: 'Trợ lý đọc giọng nói',
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
                  timer: CookingTimerPanel(
                    formattedTime: _controller.formattedTime,
                    isRunning: _controller.isTimerRunning,
                    onToggle: _controller.toggleTimer,
                    onReset: _controller.resetTimer,
                  ),
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
