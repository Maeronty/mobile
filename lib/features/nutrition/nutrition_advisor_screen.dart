// =============================================================================
// MÀN HÌNH: DINH DƯỠNG & THỰC ĐƠN AI (Nutrition Advisor)
// =============================================================================
//
// FILE NÀY CHỈ CHỨA GIAO DIỆN. Lựa chọn và logic tạo thực đơn nằm trong
// `nutrition_controller.dart`.
//
// FLOW UI
//   1. initState → tạo NutritionController (đã có sẵn thực đơn mặc định).
//   2. Chọn "Đối tượng" & "Mục tiêu" bằng ChoiceChip.
//   3. Bấm "Tạo lại thực đơn thông minh" → `_generateNewPlan` → chờ controller
//      tạo xong → SnackBar báo thành công.
//   4. Chọn ngày → xem tổng calo, tóm tắt dinh dưỡng và danh sách bữa ăn.
//
// LƯU Ý: Màn hình này hiện chưa được gắn vào thanh điều hướng.
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'nutrition_controller.dart';

class NutritionAdvisorScreen extends StatefulWidget {
  const NutritionAdvisorScreen({super.key});

  @override
  State<NutritionAdvisorScreen> createState() => _NutritionAdvisorScreenState();
}

class _NutritionAdvisorScreenState extends State<NutritionAdvisorScreen> {
  final NutritionController _controller = NutritionController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  Future<void> _generateNewPlan() async {
    final done = await _controller.generatePlan();
    if (!done || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã tạo thành công thực đơn cho mục tiêu "${_controller.selectedHealthGoal}"!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dailyPlans = _controller.dailyPlans;
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
            // Top Advisor Banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cố Vấn Dinh Dưỡng Bếp Việt',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Thiết kế thực đơn khoa học phù hợp với nhu cầu cơ thể bạn',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Target Group Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                '1. Đối tượng áp dụng:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: NutritionController.targetGroups.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final group = NutritionController.targetGroups[index];
                  final isSelected = group.id == _controller.selectedTargetGroup;
                  return ChoiceChip(
                    label: Text('${group.label} (${group.sub})'),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) => _controller.selectTargetGroup(group.id),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Health Goals Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                '2. Mục tiêu sức khỏe:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: NutritionController.healthGoals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final goal = NutritionController.healthGoals[index];
                  final isSelected = goal.id == _controller.selectedHealthGoal;
                  return ChoiceChip(
                    label: Text('${goal.label} - ${goal.sub}'),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) => _controller.selectHealthGoal(goal.id),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Generate Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: AppColors.primary,
                ),
                icon: _controller.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _controller.isLoading ? 'Đang tạo thực đơn...' : 'Tạo lại thực đơn thông minh',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _controller.isLoading ? null : _generateNewPlan,
              ),
            ),

            const SizedBox(height: 24),

            // Day Selector Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lịch trình các ngày trong tuần',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${dailyPlans.length} ngày',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: dailyPlans.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final day = dailyPlans[index];
                  final isSelected = index == _controller.selectedDayIndex;
                  return FilterChip(
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    label: Text(day.dayName),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => _controller.selectDay(index),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Day Summary Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.dividerDark
                        : AppColors.dividerLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${activeDayPlan.dayName} - Tổng calo:',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${activeDayPlan.totalCalories} kcal',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activeDayPlan.nutritionSummary,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Meal items list (Sáng, Trưa, Tối, Phụ)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: activeDayPlan.meals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final meal = activeDayPlan.meals[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dish Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: Image.asset(
                            meal.imageAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    meal.mealType,
                                    style: const TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${meal.calories} kcal',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentOrange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meal.dishName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('Đạm: ${meal.proteinGrams.toInt()}g', style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 8),
                                Text('Carb: ${meal.carbsGrams.toInt()}g', style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 8),
                                Text('Béo: ${meal.fatGrams.toInt()}g', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meal.tip,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMutedLight,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

