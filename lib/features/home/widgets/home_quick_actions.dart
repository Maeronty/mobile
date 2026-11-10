// =============================================================================
// WIDGET: HAI PHÍM TẮT NHANH (Home) — "Tủ lạnh còn gì?" & "Surprise Me"
// =============================================================================
//
// FLOW
//   Nhấn ô trái → chuyển sang tab Túi Thần Kỳ; ô phải → mở Surprise Me.
//   Mỗi ô có phản hồi nhấn (Pressable) và gradient riêng.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/motion/pressable.dart';
import '../../../core/widgets/mystery_plate_icon.dart';

class HomeQuickActions extends StatelessWidget {
  final VoidCallback onOpenPantry;
  final VoidCallback onOpenSurprise;

  const HomeQuickActions({super.key, required this.onOpenPantry, required this.onOpenSurprise});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              colors: const [Color(0xFF059669), Color(0xFF10B981)],
              icon: const Icon(Icons.kitchen_rounded, color: Colors.white, size: 24),
              title: 'Tủ lạnh còn gì?',
              subtitle: 'Gợi ý từ nguyên liệu',
              onTap: onOpenPantry,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickAction(
              colors: const [Color(0xFFEA580C), Color(0xFFF97316)],
              icon: const MysteryPlateIcon(color: Colors.white, size: 24),
              title: 'Surprise Me',
              subtitle: 'Để bếp chọn giúp',
              onTap: onOpenSurprise,
            ),
          ),
        ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(height: 10),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
