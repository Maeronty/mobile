import '../models/user_profile.dart';

class MockData {
  static final UserProfile currentUser = const UserProfile(
    id: 'u_101',
    name: 'Đầu Bếp Minh Nhật',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    role: 'VIP Chef',
    bio: 'Yêu ẩm thực Việt & đam mê sáng tạo món ăn lành mạnh cho gia đình.',
    savedRecipesCount: 14,
    cookedCount: 52,
    followersCount: 340,
    isPro: true,
  );

}
