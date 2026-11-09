// Model người dùng (hồ sơ cá nhân). Trước đây nằm chung file post.dart
// với model bài viết cộng đồng — feature Cộng đồng đã được gỡ bỏ.

class UserProfile {
  final String id;
  final String name;
  final String avatarUrl;
  final String role; // "Chef", "VIP", "Member", "Admin"
  final String bio;
  final int savedRecipesCount;
  final int cookedCount;
  final int followersCount;
  final bool isPro;

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.role,
    required this.bio,
    this.savedRecipesCount = 12,
    this.cookedCount = 45,
    this.followersCount = 180,
    this.isPro = true,
  });
}
