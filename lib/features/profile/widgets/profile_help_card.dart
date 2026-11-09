// =============================================================================
// WIDGET: NHÓM HỖ TRỢ & CHÍNH SÁCH (Hồ sơ)
// =============================================================================
//
// FLOW
//   Chạm từng mục → hiện SnackBar thông tin (chưa có màn hình riêng).
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'profile_section_card.dart';

class ProfileHelpCard extends StatelessWidget {
  const ProfileHelpCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      children: [
        ListTile(
          leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
          title: const Text('Trung tâm hỗ trợ & Góp ý'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hỗ trợ: support@tomato-foodtip.vn')),
            );
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.policy_outlined, color: AppColors.primary),
          title: const Text('Điều khoản sử dụng & Chính sách'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bản quyền thuộc về Bếp Việt Food Tip System.')),
            );
          },
        ),
      ],
    );
  }
}
