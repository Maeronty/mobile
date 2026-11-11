// =============================================================================
// WIDGET: PHÍM TẮT NHANH (Home) — "Surprise Me"
// =============================================================================
//
// FLOW
//   Nhấn ô → mở Surprise Me. Ô có phản hồi nhấn (Pressable) và gradient riêng.
//   (Ô "Tủ lạnh còn gì?" đã được gỡ cùng chức năng Tủ lạnh.)
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/motion/pressable.dart';
import '../../../core/widgets/mystery_plate_icon.dart';

class HomeQuickActions extends StatelessWidget {
  final VoidCallback onOpenSurprise;

  const HomeQuickActions({super.key, required this.onOpenSurprise});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _QuickAction(
        colors: const [Color(0xFFEA580C), Color(0xFFF97316)],
        icon: const MysteryPlateIcon(color: Colors.white, size: 24),
        title: 'Surprise Me',
        subtitle: 'Không biết nấu gì? Để bếp chọn giúp',
        onTap: onOpenSurprise,
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final List<Color> colors;
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: '$title. $subtitle',
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.9)),
            ],
          ),
        ),
      ),
    );
  }
}
