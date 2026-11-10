// =============================================================================
// WIDGET: ẢNH MẠNG CÓ HIỆU ỨNG (AppNetworkImage)
// =============================================================================
//
// FLOW
//   1. Đổi link qua `ApiClient.imageUrl` (web → proxy có CORS).
//   2. Giải mã ảnh đúng kích thước hiển thị (`cacheWidth` = bề rộng × mật độ
//      điểm ảnh) → ảnh 1024 px hiển thị ở thẻ 180 px không chiếm RAM thừa,
//      cuộn danh sách dài vẫn mượt.
//   3. Đang tải → nền xám nhạt; tải xong → ảnh mờ dần hiện ra (280 ms).
//      Ảnh đã có trong bộ nhớ đệm → hiện ngay, không nháy.
//   4. Lỗi / không có link → biểu tượng món ăn.
// =============================================================================

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../motion/motion.dart';

class AppNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Alignment alignment;

  const AppNetworkImage({super.key, required this.url, this.fit = BoxFit.cover, this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF263244)
        : const Color(0xFFE7ECF2);
    final placeholder = ColoredBox(color: placeholderColor);
    if (url.isEmpty) return _fallback(placeholderColor);

    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final width = constraints.maxWidth.isFinite ? (constraints.maxWidth * dpr).round() : null;
        return Image.network(
          ApiClient.imageUrl(url),
          fit: fit,
          alignment: alignment,
          cacheWidth: width,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return Stack(
              fit: StackFit.passthrough,
              children: [
                placeholder,
                AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: Motion.reduced(context) ? Duration.zero : Motion.medium,
                  curve: Motion.enter,
                  child: child,
                ),
              ],
            );
          },
          errorBuilder: (context, error, stackTrace) => _fallback(placeholderColor),
        );
      },
    );
  }

  Widget _fallback(Color color) => ColoredBox(
        color: color,
        child: const Center(child: Icon(Icons.restaurant_rounded, size: 36, color: Colors.grey)),
      );
}
