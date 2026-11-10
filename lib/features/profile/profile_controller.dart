// =============================================================================
// FEATURE: HỒ SƠ NGƯỜI DÙNG & CÀI ĐẶT (Profile & Settings)
// =============================================================================
//
// VAI TRÒ
//   - Giữ thông tin người dùng đang đăng nhập (`currentUser`).
//   - Lưu các tuỳ chọn cá nhân: chế độ ăn uống, bật/tắt thông báo.
//   (Dark Mode thuộc feature riêng: features/theme/theme_controller.dart)
//
// FLOW
//   1. `currentUser`: đã đăng nhập → tên/vai trò lấy từ AuthController;
//      khách → hồ sơ mẫu trong MockData với tên "Khách".
//      Các số liệu thống kê (đã lưu, đã nấu...) vẫn là dữ liệu mẫu.
//   2. Bấm "Chế độ ăn uống" → ProfileScreen mở dialog liệt kê `dietOptions`
//      → chọn 1 mục → `setDietPreference(opt)` → notifyListeners.
//   3. Gạt công tắc "Thông báo" → `setNotificationEnabled(val)`.
//   4. Bấm thẻ nâng cấp → mở PricingScreen (chỉ là giao diện, không có logic).
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/mock_data.dart';
import '../../core/models/user_profile.dart';
import '../auth/auth_controller.dart';

class ProfileController extends ChangeNotifier {
  /// Singleton: thông tin người dùng dùng chung toàn app.
  static final ProfileController instance = ProfileController._();

  ProfileController._();

  /// Các lựa chọn chế độ ăn hiển thị trong dialog.
  static const List<String> dietOptions = [
    'Cân bằng & Đa dạng',
    'Eat Clean hữu cơ',
    'Keto / Low-Carb',
    'Thuần chay (Vegan)',
    'Ăn chay có trứng sữa',
  ];

  String _dietPreference = dietOptions.first;
  bool _notificationEnabled = true;

  UserProfile get currentUser {
    final sample = MockData.currentUser;
    final user = AuthController.instance.user;
    return UserProfile(
      id: user?.userId.toString() ?? 'guest',
      name: user?.displayName ?? 'Khách',
      avatarUrl: user?.avatarUrl ?? sample.avatarUrl,
      role: user?.role ?? 'Khách',
      bio: user != null ? '@${user.username} · ${user.email}' : 'Đăng nhập để lưu món yêu thích và dùng gợi ý AI.',
      savedRecipesCount: sample.savedRecipesCount,
      cookedCount: sample.cookedCount,
      followersCount: sample.followersCount,
      isPro: user != null && sample.isPro,
    );
  }
  String get dietPreference => _dietPreference;
  bool get notificationEnabled => _notificationEnabled;

  void setDietPreference(String value) {
    _dietPreference = value;
    notifyListeners();
  }

  void setNotificationEnabled(bool value) {
    _notificationEnabled = value;
    notifyListeners();
  }
}
