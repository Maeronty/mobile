// =============================================================================
// MÀN HÌNH: GÓI NÂNG CẤP "BẾP VIỆT PRO VIP" (Pricing)
// =============================================================================
//
// Màn hình tĩnh, chỉ hiển thị 2 gói (Cơ Bản miễn phí / Đầu Bếp VIP). Chưa tích
// hợp thanh toán nên không có controller. Được mở từ ProfileScreen.
// Các khu vực giao diện nằm trong `widgets/pricing_*.dart`.
// =============================================================================

import 'package:flutter/material.dart';
import 'widgets/pricing_header.dart';
import 'widgets/pricing_plan_card.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói Dịch Vụ Bếp Việt Pro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const PricingHeader(),

            const SizedBox(height: 24),

            // Plan 1: Free
            const PricingPlanCard(
              title: 'Cơ Bản (Miễn Phí)',
              price: '0 đ',
              period: 'Mãi mãi',
              features: [
                'Tìm kiếm công thức nấu ăn cơ bản',
                'Quản lý tối đa 10 nguyên liệu tủ lạnh',
                'Xem bảng dinh dưỡng tiêu chuẩn',
                'Tham gia cộng đồng người yêu bếp',
              ],
              buttonText: 'Gói hiện tại',
            ),

            const SizedBox(height: 16),

            // Plan 2: Pro Chef (Recommended)
            const PricingPlanCard(
              title: 'Đầu Bếp VIP (Bếp Việt Pro)',
              price: '69.000 đ',
              period: 'tháng',
              isRecommended: true,
              features: [
                'Không giới hạn nguyên liệu tủ lạnh',
                'AI Vision nhận diện nguyên liệu qua camera',
                'Thực đơn dinh dưỡng cá nhân hóa 7 ngày',
                'Chế độ nấu ăn rảnh tay (Hand-free Voice Mode)',
                'Huy hiệu Bếp Trưởng Danh Dự trên cộng đồng',
                'Tải PDF thực đơn và danh sách đi chợ',
              ],
              buttonText: 'Gia hạn gói VIP',
            ),
          ],
        ),
      ),
    );
  }
}
