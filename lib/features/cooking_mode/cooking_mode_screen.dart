// =============================================================================
// MÀN HÌNH: CHẾ ĐỘ NẤU ĂN TOÀN MÀN HÌNH (Cooking Mode)
// =============================================================================
//
// FILE NÀY CHỈ CHỨA GIAO DIỆN. Logic chuyển bước, đồng hồ đếm ngược và giọng
// nói nằm trong `cooking_mode_controller.dart`.
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
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.alarm_on_rounded, color: AppColors.accent, size: 28),
            SizedBox(width: 8),
            Text('Hết giờ!'),
          ],
        ),
        content: Text('Đã hoàn thành thời gian cho bước ${_controller.currentStepIndex + 1}. Bạn có thể chuyển sang bước tiếp theo!'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
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
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration_rounded, color: Colors.amber, size: 30),
            SizedBox(width: 8),
            Text('Chúc mừng!'),
          ],
        ),
        content: Text('Bạn đã hoàn tất món ăn "${widget.recipe.title}". Chúc bạn và gia đình có một bữa ăn thật ngon miệng!'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit cooking mode
            },
            child: const Text('Hoàn tất nấu ăn'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _controller.currentStep;
    final totalSteps = _controller.totalSteps;
    final progress = _controller.progress;

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
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bước ${_controller.currentStepIndex + 1} / $totalSteps',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Step Card
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'HƯỚNG DẪN BƯỚC ${_controller.currentStepIndex + 1}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Step Content
                      Text(
                        currentStep.description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // Chef Tip
                      if (currentStep.tip != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Mẹo đầu bếp: ${currentStep.tip}',
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Timer Container
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Đồng hồ đếm ngược',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _controller.formattedTime,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton.filled(
                                    style: IconButton.styleFrom(
                                      backgroundColor: _controller.isTimerRunning ? AppColors.accent : AppColors.primary,
                                      padding: const EdgeInsets.all(14),
                                    ),
                                    icon: Icon(_controller.isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                                    onPressed: _controller.toggleTimer,
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton.outlined(
                                    style: IconButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(color: Colors.white24),
                                    ),
                                    icon: const Icon(Icons.refresh_rounded),
                                    onPressed: _controller.resetTimer,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Navigation Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (_controller.currentStepIndex > 0)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Bước trước'),
                        onPressed: _controller.prevStep,
                      ),
                    ),
                  if (_controller.currentStepIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(
                        _controller.currentStepIndex == totalSteps - 1
                            ? Icons.check_circle_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        _controller.currentStepIndex == totalSteps - 1
                            ? 'Hoàn thành món ăn'
                            : 'Bước tiếp theo',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: _nextStep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

