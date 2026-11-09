// =============================================================================
// WIDGET: GIAO DIỆN THIẾT LẬP BỘ LỌC (Surprise Me — trạng thái Setup)
// =============================================================================
//
// FLOW
//   1. Chọn Thể loại / Thời gian / Độ khó → SurpriseMeController cập nhật
//      → SurpriseMeScreen build lại → số món khớp ở thanh đáy đổi theo.
//   2. Bấm "Đầu bếp bí mật, nấu ngay!" → controller.startCooking.
// =============================================================================

import 'package:flutter/material.dart';
import '../surprise_me_controller.dart';
import 'surprise_category_filter.dart';
import 'surprise_filter_chip.dart';
import 'surprise_intro_banner.dart';
import 'surprise_start_bar.dart';

class SurpriseSetupView extends StatelessWidget {
  final SurpriseMeController controller;

  const SurpriseSetupView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SurpriseIntroBanner(),

                const SizedBox(height: 24),

                // 1. Thể loại món ăn
                SurpriseCategoryFilter(
                  categories: SurpriseMeController.availableCategories,
                  selected: controller.selectedCategories,
                  onToggle: controller.toggleCategory,
                ),

                const SizedBox(height: 24),

                // 2. Thời gian nấu
                const Text(
                  'Thời gian chế biến',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SurpriseFilterChip(
                      label: 'Nhanh (≤ 20p)',
                      isSelected: controller.selectedTimeFilter == 1,
                      onTap: () => controller.setTimeFilter(1),
                    ),
                    SurpriseFilterChip(
                      label: 'Vừa (21 - 40p)',
                      isSelected: controller.selectedTimeFilter == 2,
                      onTap: () => controller.setTimeFilter(2),
                    ),
                    SurpriseFilterChip(
                      label: 'Kỹ (> 40p)',
                      isSelected: controller.selectedTimeFilter == 3,
                      onTap: () => controller.setTimeFilter(3),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 3. Độ khó
                const Text(
                  'Độ khó',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SurpriseMeController.availableDifficulties.map((diff) {
                    return SurpriseFilterChip(
                      label: diff,
                      isSelected: controller.selectedDifficulty == diff,
                      onTap: () => controller.setDifficulty(diff),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        // Thanh CTA dính đáy
        SurpriseStartBar(
          matchCount: controller.matchingRecipes.length,
          onStart: controller.startCooking,
        ),
      ],
    );
  }
}
