// =============================================================================
// WIDGET: ẢNH BÌA + THANH TRÊN CÙNG (Chi tiết công thức)
// =============================================================================
//
// MOTION
//   - Ảnh bay từ thẻ vừa bấm tới đây (Hero [heroTag]) → không có khoảng trống
//     chờ tải; ảnh, tên, danh mục có ngay từ bản tóm tắt.
//   - Cuộn lên: ảnh thu lại thành thanh trên cùng (SliverAppBar pinned), ảnh
//     phóng nhẹ khi kéo quá đầu trang (stretch), tên món nhỏ hiện dần ở thanh.
//
// FLOW
//   Nút quay lại → đóng màn. Nút chia sẻ → SnackBar demo.
//   Nút tim → [onToggleFavorite]; null khi chưa tải xong thì ẩn nút.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_network_image.dart';

class RecipeDetailAppBar extends StatelessWidget {
  final String title;
  final String category;
  final String imageUrl;
  final String heroTag;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const RecipeDetailAppBar({
    super.key,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.heroTag,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  static const double expandedHeight = 320;

  Widget _circleButton({required Widget icon, required VoidCallback onPressed, required String tooltip}) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.black.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: IconButton(icon: icon, onPressed: onPressed, tooltip: tooltip, visualDensity: VisualDensity.compact),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      leading: _circleButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
        tooltip: 'Quay lại',
      ),
      actions: [
        _circleButton(
          icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
          tooltip: 'Chia sẻ',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã sao chép liên kết công thức!'), duration: Duration(seconds: 2)),
          ),
        ),
        if (onToggleFavorite != null)
          _circleButton(
            tooltip: isFavorite ? 'Bỏ yêu thích' : 'Yêu thích',
            onPressed: onToggleFavorite!,
            icon: AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(isFavorite),
                color: isFavorite ? AppColors.accent : Colors.white,
                size: 20,
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // 0 = đang mở rộng hết, 1 = đã thu thành thanh.
          final collapsed = ((expandedHeight - constraints.maxHeight) / (expandedHeight - kToolbarHeight - topPadding))
              .clamp(0.0, 1.0);
          return FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            centerTitle: false,
            titlePadding: const EdgeInsetsDirectional.only(start: 64, end: 104, bottom: 16),
            title: Opacity(
              opacity: collapsed > 0.8 ? (collapsed - 0.8) * 5 : 0,
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                Hero(tag: heroTag, child: AppNetworkImage(url: imageUrl)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.25, 0.55, 1],
                      colors: [Color(0x66000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Opacity(
                    opacity: 1 - collapsed,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                            child: Text(category.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 26, height: 1.2, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
