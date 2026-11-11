// =============================================================================
// FEATURE: HỒ SƠ NGƯỜI DÙNG & CÀI ĐẶT (Profile & Settings)
// =============================================================================
//
// VAI TRÒ
//   - Giữ thông tin người dùng đang đăng nhập (`currentUser`).
//   - Lưu tuỳ chọn cá nhân: bật/tắt thông báo.
//   (Dark Mode thuộc feature riêng: features/theme/theme_controller.dart)
//
// FLOW
//   1. `currentUser`: đã đăng nhập → tên, email lấy từ AuthController;
//      khách → hồ sơ mẫu trong MockData với tên "Khách".
//      Các số liệu thống kê (đã lưu, đã nấu...) vẫn là dữ liệu mẫu.
//   2. Gạt công tắc "Thông báo" → `setNotificationEnabled(val)`.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/mock_data.dart';
import '../../core/models/user_profile.dart';
import '../auth/auth_controller.dart';

class ProfileController extends ChangeNotifier {
  /// Singleton: thông tin người dùng dùng chung toàn app.
  static final ProfileController instance = ProfileController._();

  ProfileController._();

  bool _notificationEnabled = true;

  UserProfile get currentUser {
    final sample = MockData.currentUser;
    final user = AuthController.instance.user;
    return UserProfile(
      id: user?.userId.toString() ?? 'guest',
      name: user?.displayName ?? 'Khách',
      avatarUrl: user?.avatarUrl ?? sample.avatarUrl,
      bio: user != null ? '@${user.username} · ${user.email}' : 'Đăng nhập để lưu món yêu thích và dùng gợi ý AI.',
      savedRecipesCount: sample.savedRecipesCount,
      cookedCount: sample.cookedCount,
      followersCount: sample.followersCount,
    );
  }
  bool get notificationEnabled => _notificationEnabled;

  void setNotificationEnabled(bool value) {
    _notificationEnabled = value;
    notifyListeners();
  }
}
