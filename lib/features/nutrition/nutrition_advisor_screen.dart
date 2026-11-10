// =============================================================================
// MÀN HÌNH: DINH DƯỠNG & THỰC ĐƠN AI (Nutrition Advisor)
// =============================================================================
//
// FILE NÀY CHỈ GHÉP CÁC KHU VỰC GIAO DIỆN; từng khu vực nằm trong `widgets/`.
// Lựa chọn và logic tạo thực đơn nằm trong `nutrition_controller.dart`.
//
// FLOW UI
//   1. initState → tạo NutritionController (đã có sẵn thực đơn mặc định).
//   2. Chọn "Đối tượng" & "Mục tiêu" bằng ChoiceChip.
//   3. Bấm "Tạo lại thực đơn thông minh" → `_generateNewPlan` → chờ controller
//      tạo xong → SnackBar báo thành công.
//   4. Chọn ngày → xem tổng calo, tóm tắt dinh dưỡng và danh sách bữa ăn.
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'nutrition_controller.dart';
import 'widgets/nutrition_advisor_banner.dart';
import 'widgets/nutrition_day_selector.dart';
import 'widgets/nutrition_day_summary_card.dart';
import 'widgets/nutrition_generate_button.dart';
import 'widgets/nutrition_meal_card.dart';
import 'widgets/nutrition_option_selector.dart';

class NutritionAdvisorScreen extends StatefulWidget {
  final NutritionController? controller;

  const NutritionAdvisorScreen({super.key, this.controller});

  @override
  State<NutritionAdvisorScreen> createState() => _NutritionAdvisorScreenState();
}

class _NutritionAdvisorScreenState extends State<NutritionAdvisorScreen> {
  late final NutritionController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? NutritionController();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  Future<void> _generateNewPlan() async {
    final done = await _controller.generatePlan();
    if (!mounted) return;

    if (!done) {
      final msg = _controller.errorMessage ??
          'Không thể tạo thực đơn từ Gemini. Vui lòng thử lại.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã tạo thành công thực đơn cho mục tiêu "${_controller.selectedHealthGoal}"!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeDayPlan = _controller.activeDayPlan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dinh Dưỡng & Thực Đơn AI'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NutritionAdvisorBanner(),

            NutritionOptionSelector(
              title: '1. Đối tượng áp dụng:',
              options: NutritionController.targetGroups,
              selectedId: _controller.selectedTargetGroup,
              labelBuilder: (group) => '${group.label} (${group.sub})',
              onSelected: _controller.selectTargetGroup,
            ),

            const SizedBox(height: 16),

            NutritionOptionSelector(
              title: '2. Mục tiêu sức khỏe:',
              options: NutritionController.healthGoals,
              selectedId: _controller.selectedHealthGoal,
              labelBuilder: (goal) => '${goal.label} - ${goal.sub}',
              onSelected: _controller.selectHealthGoal,
            ),

            const SizedBox(height: 16),

            NutritionGenerateButton(
              isLoading: _controller.isLoading,
              onPressed: _generateNewPlan,
            ),

            const SizedBox(height: 24),

            NutritionDaySelector(
              days: _controller.dailyPlans,
              selectedIndex: _controller.selectedDayIndex,
              onSelected: _controller.selectDay,
            ),

            const SizedBox(height: 16),

            NutritionDaySummaryCard(day: activeDayPlan),

            const SizedBox(height: 16),

            // Meal items list (Sáng, Trưa, Tối, Phụ)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: activeDayPlan.meals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  NutritionMealCard(meal: activeDayPlan.meals[index]),
            ),
          ],
        ),
      ),
    );
  }
}
