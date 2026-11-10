// =============================================================================
// WIDGET: THANH DANH MỤC DÍNH TRÊN ĐẦU KHI CUỘN (Home)
// =============================================================================
//
// FLOW
//   - Là một SliverPersistentHeader `pinned`: cuộn qua banner thì thanh chip
//     dính lại ở đầu màn hình, luôn đổi danh mục được.
//   - Khi đã dính (nội dung trượt bên dưới) → hiện bóng mờ nhẹ để tách lớp.
//   - Chip đang chọn: nền xanh, chữ trắng; đổi chọn bằng AnimatedContainer.
//     Chip được chọn tự cuộn vào giữa tầm nhìn (Scrollable.ensureVisible).
//   - Mỗi chip kèm số món của danh mục.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/models/recipe_summary.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';

class HomeCategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final List<CategoryCount> categories;
  final int allCount;
  final String? selected;
  final ValueChanged<String?> onSelected;

  HomeCategoryBarDelegate({
    required this.categories,
    required this.allCount,
    required this.selected,
    required this.onSelected,
  });

  static const double height = 60;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: Motion.medium,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: overlapsContent || shrinkOffset > 0
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))]
            : const [],
      ),
      child: _CategoryChips(categories: categories, allCount: allCount, selected: selected, onSelected: onSelected),
    );
  }

  @override
  bool shouldRebuild(HomeCategoryBarDelegate old) =>
      old.selected != selected || old.categories != categories || old.allCount != allCount;
}

class _CategoryChips extends StatefulWidget {
  final List<CategoryCount> categories;
  final int allCount;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _CategoryChips({required this.categories, required this.allCount, required this.selected, required this.onSelected});

  @override
  State<_CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<_CategoryChips> {
  final Map<String?, GlobalKey> _keys = {};

  GlobalKey _keyFor(String? name) => _keys.putIfAbsent(name, GlobalKey.new);

  @override
  void didUpdateWidget(covariant _CategoryChips old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keyFor(widget.selected).currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Motion.medium, curve: Motion.enter);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = <(String?, String, int)>[
      (null, 'Tất cả', widget.allCount),
      for (final c in widget.categories) (c.name, c.name, c.count),
    ];
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final (value, label, count) = entries[i];
        return _Chip(
          key: _keyFor(value),
          label: label,
          count: count,
          selected: value == widget.selected,
          onTap: () => widget.onSelected(value),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({super.key, required this.label, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final idleBg = dark ? AppColors.surfaceDark : Colors.white;
    final idleFg = dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : idleBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.primary : (dark ? AppColors.dividerDark : AppColors.dividerLight)),
          ),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (count > 0)
                TextSpan(
                  text: '  $count',
                  style: TextStyle(fontSize: 11.5, color: selected ? Colors.white70 : Colors.grey),
                ),
            ]),
            style: TextStyle(fontSize: 13.5, color: selected ? Colors.white : idleFg),
          ),
        ),
      ),
    );
  }
}
