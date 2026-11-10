// Model người dùng đã đăng nhập, đọc từ response `POST /api/Account/login|register`
// của backend Rust (`AuthResponse` trong backend/src/models/user.rs, camelCase).

class AuthUser {
  final int userId;
  final String username;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String role;

  const AuthUser({
    required this.userId,
    required this.username,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final username = json['username'] as String;
    final displayName = json['displayName'] as String?;
    return AuthUser(
      userId: json['userId'] as int,
      username: username,
      email: json['email'] as String,
      displayName: displayName == null || displayName.trim().isEmpty ? username : displayName,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'User',
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'role': role,
      };
}
