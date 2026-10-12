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

class PostComment {
  final String id;
  final String userName;
  final String userAvatar;
  final String userRole;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final bool isLiked;
  final bool isAuthor;

  const PostComment({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.userRole,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
    this.isAuthor = false,
  });

  PostComment copyWith({
    int? likesCount,
    bool? isLiked,
  }) {
    return PostComment(
      id: id,
      userName: userName,
      userAvatar: userAvatar,
      userRole: userRole,
      content: content,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      isAuthor: isAuthor,
    );
  }
}

class CommunityPost {
  final String id;
  final UserProfile author;
  final String title;
  final String content;
  final String imageAsset;
  final List<String> tags;
  final DateTime createdAt;
  final int likesCount;
  final bool isLiked;
  final List<PostComment> comments;

  const CommunityPost({
    required this.id,
    required this.author,
    required this.title,
    required this.content,
    required this.imageAsset,
    required this.tags,
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
    this.comments = const [],
  });

  CommunityPost copyWith({
    int? likesCount,
    bool? isLiked,
    List<PostComment>? comments,
  }) {
    return CommunityPost(
      id: id,
      author: author,
      title: title,
      content: content,
      imageAsset: imageAsset,
      tags: tags,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      comments: comments ?? this.comments,
    );
  }
}

