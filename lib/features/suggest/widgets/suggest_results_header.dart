// =============================================================================
// WIDGET: TIÊU ĐỀ KẾT QUẢ ĐỀ XUẤT (màn Gợi ý)
// =============================================================================
//
// FLOW
//   Nút "Xóa tất cả" chỉ hiện khi `showClearAll = true` → `onClearAll`.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SuggestResultsHeader extends StatelessWidget {
  final int resultCount;
  final bool showClearAll;
  final VoidCallback onClearAll;

  const SuggestResultsHeader({
    super.key,
    required this.resultCount,
    required this.showClearAll,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Kết quả đề xuất ($resultCount món)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (showClearAll)
            InkWell(
              onTap: onClearAll,
              child: const Text(
                'Xóa tất cả',
                style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
