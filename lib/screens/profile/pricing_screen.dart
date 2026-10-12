import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói Dịch Vụ Tomato Pro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Pro Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 48, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    'Nâng Tầm Bếp Trưởng Tại Gia',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Mở khóa toàn bộ tính năng cao cấp cùng Cố vấn dinh dưỡng AI không giới hạn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Plan 1: Free
            _buildPlanCard(
              context,
              title: 'Cơ Bản (Miễn Phí)',
              price: '0 đ',
              period: 'Mãi mãi',
              features: [
                'Tìm kiếm công thức nấu ăn cơ bản',
                'Quản lý tối đa 10 nguyên liệu tủ lạnh',
                'Xem bảng dinh dưỡng tiêu chuẩn',
                'Tham gia cộng đồng người yêu bếp',
              ],
              isCurrent: false,
              buttonText: 'Gói hiện tại',
            ),

            const SizedBox(height: 16),

            // Plan 2: Pro Chef (Recommended)
            _buildPlanCard(
              context,
              title: 'Đầu Bếp VIP (Tomato Pro)',
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
              isCurrent: true,
              buttonText: 'Gia hạn gói VIP',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    required String period,
    required List<String> features,
    bool isRecommended = false,
    bool isCurrent = false,
    required String buttonText,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecommended ? AppColors.primary : AppColors.dividerLight,
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRecommended)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'PHỔ BIẾN NHẤT',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isRecommended ? AppColors.primary : null,
                ),
              ),
              const SizedBox(width: 4),
              Text('/ $period', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const Divider(height: 24),
          ...features.map((feat) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: isRecommended ? AppColors.primary : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(feat, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              backgroundColor: isRecommended ? AppColors.primary : Colors.grey.shade300,
              foregroundColor: isRecommended ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Bạn đã chọn: $title')),
              );
            },
            child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
