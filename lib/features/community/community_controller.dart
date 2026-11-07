// =============================================================================
// FEATURE: CỘNG ĐỒNG ẨM THỰC (Community Feed)
// =============================================================================
//
// VAI TRÒ
//   Quản lý bảng tin cộng đồng: danh sách bài viết, thả tim, bình luận,
//   đăng bài mới. Tác giả bài/bình luận là người dùng hiện tại
//   (ProfileController.currentUser).
//
// FLOW
//   ▸ THẢ TIM `toggleLike(postId)`
//       1. Tìm bài theo id (không thấy → bỏ qua).
//       2. Đảo trạng thái isLiked; likesCount +1 khi thích, −1 khi bỏ thích
//          (chặn không cho âm).
//       3. Thay bài cũ bằng bản copy mới (dữ liệu bất biến) → notify.
//
//   ▸ BÌNH LUẬN `addComment(postId, content)`
//       1. Nội dung rỗng (sau trim) → bỏ qua.
//       2. Tạo PostComment với id = 'c_<timestamp>', tác giả = currentUser.
//       3. Nối vào cuối danh sách bình luận của bài → notify.
//
//   ▸ ĐĂNG BÀI `createPost(...)`
//       1. Tạo CommunityPost id = 'p_<timestamp>', tác giả = currentUser.
//       2. Ảnh rỗng → dùng ảnh mặc định phở; bài mới tự có 1 tim của chính mình.
//       3. Chèn lên ĐẦU bảng tin (bài mới nhất hiển thị trước) → notify.
//
// LƯU Ý
//   - CommunityScreen hiện CHƯA được gắn vào thanh điều hướng (xem
//     lib/app/main_navigation_screen.dart) — feature đã sẵn sàng để bật lại.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../core/data/mock_data.dart';
import '../../core/models/post.dart';
import '../profile/profile_controller.dart';

class CommunityController extends ChangeNotifier {
  /// Singleton: bảng tin dùng chung.
  static final CommunityController instance = CommunityController._();

  CommunityController._() : _posts = List.of(MockData.communityPosts);

  /// Ảnh dùng khi người dùng không chọn ảnh cho bài viết.
  static const String defaultPostImage = 'assets/images/pho.png';

  final List<CommunityPost> _posts;

  /// Bài viết theo thứ tự hiển thị (mới nhất ở đầu).
  List<CommunityPost> get posts => List.unmodifiable(_posts);

  /// Lấy bản mới nhất của một bài (dùng cho bottom sheet bình luận để thấy
  /// bình luận vừa thêm). Không tìm thấy → trả về [fallback].
  CommunityPost findPost(String postId, {required CommunityPost fallback}) {
    return _posts.firstWhere((p) => p.id == postId, orElse: () => fallback);
  }

  void toggleLike(String postId) {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = _posts[idx];
    final newIsLiked = !post.isLiked;
    final newLikes = newIsLiked ? post.likesCount + 1 : post.likesCount - 1;

    _posts[idx] = post.copyWith(
      isLiked: newIsLiked,
      likesCount: newLikes < 0 ? 0 : newLikes,
    );
    notifyListeners();
  }

  void addComment(String postId, String content) {
    final clean = content.trim();
    if (clean.isEmpty) return;

    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final user = ProfileController.instance.currentUser;
    final post = _posts[idx];
    final newComment = PostComment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      userName: user.name,
      userAvatar: user.avatarUrl,
      userRole: user.role,
      content: clean,
      createdAt: DateTime.now(),
      likesCount: 0,
      isLiked: false,
      isAuthor: false,
    );

    _posts[idx] = post.copyWith(comments: [...post.comments, newComment]);
    notifyListeners();
  }

  void createPost({
    required String title,
    required String content,
    required String imageAsset,
    required List<String> tags,
  }) {
    final newPost = CommunityPost(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      author: ProfileController.instance.currentUser,
      title: title,
      content: content,
      imageAsset: imageAsset.isNotEmpty ? imageAsset : defaultPostImage,
      tags: tags,
      createdAt: DateTime.now(),
      likesCount: 1,
      isLiked: true,
      comments: [],
    );

    _posts.insert(0, newPost);
    notifyListeners();
  }
}
