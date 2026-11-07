// =============================================================================
// MÀN HÌNH: CỘNG ĐỒNG ẨM THỰC (Community Feed)
// =============================================================================
//
// FILE NÀY CHỈ CHỨA GIAO DIỆN. Logic thả tim / bình luận / đăng bài nằm trong
// `community_controller.dart`.
//
// FLOW UI
//   1. build → đọc `CommunityController.instance.posts` và hiển thị bảng tin.
//   2. Nút "+" (FAB) → `_openCreatePostDialog` → nhập tiêu đề + nội dung, chọn
//      ảnh → "Đăng bài ngay" → createPost → đóng sheet → SnackBar.
//   3. Nút trái tim → toggleLike → setState.
//   4. Nút bình luận → `_openCommentsBottomSheet` → gửi bình luận → addComment
//      → setSheetState (cập nhật sheet) + setState (cập nhật số bình luận).
//
// LƯU Ý: Màn hình này hiện chưa được gắn vào thanh điều hướng.
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/models/post.dart';
import '../../core/theme/app_colors.dart';
import 'community_controller.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _newPostTitleController = TextEditingController();
  final TextEditingController _newPostContentController = TextEditingController();
  final TextEditingController _commentInputController = TextEditingController();

  @override
  void dispose() {
    _newPostTitleController.dispose();
    _newPostContentController.dispose();
    _commentInputController.dispose();
    super.dispose();
  }

  void _openCreatePostDialog() {
    String selectedDishImage = 'assets/images/pho.png';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chia sẻ món ăn cùng cộng đồng',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPostTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề bài viết',
                        hintText: 'VD: Cuối tuần trổ tài nấu Bún Bò...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPostContentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung chia sẻ & bí quyết',
                        hintText: 'Chia sẻ các mẹo hay khi chế biến hoặc cảm nhận của bạn...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chọn ảnh món ăn minh họa:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 70,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          'assets/images/pho.png',
                          'assets/images/banh_mi.png',
                          'assets/images/bun_bo_hue.png',
                          'assets/images/salmon.png',
                          'assets/images/steak.png',
                          'assets/images/salad.png',
                          'assets/images/pasta.png',
                        ].map((img) {
                          final isSelected = selectedDishImage == img;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedDishImage = img;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(img, fit: BoxFit.cover),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () {
                        final title = _newPostTitleController.text.trim();
                        final content = _newPostContentController.text.trim();
                        if (title.isNotEmpty && content.isNotEmpty) {
                          CommunityController.instance.createPost(
                            title: title,
                            content: content,
                            imageAsset: selectedDishImage,
                            tags: ['BếpYêuThương', 'TomatoCook'],
                          );
                          _newPostTitleController.clear();
                          _newPostContentController.clear();
                          Navigator.pop(context);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bài viết đã được đăng thành công!')),
                          );
                        }
                      },
                      child: const Text('Đăng bài ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCommentsBottomSheet(CommunityPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final community = CommunityController.instance;
            final currentPost = community.findPost(post.id, fallback: post);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: 500,
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.dividerLight)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Bình luận (${currentPost.comments.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Comments List
                    Expanded(
                      child: currentPost.comments.isEmpty
                          ? const Center(
                              child: Text('Chưa có bình luận nào. Hãy là người đầu tiên!'),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: currentPost.comments.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final comment = currentPost.comments[index];
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primaryLight,
                                      child: Text(
                                        comment.userName.substring(0, 1),
                                        style: const TextStyle(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF0F172A)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    comment.userName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    comment.userRole,
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primaryDark,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(comment.content, style: const TextStyle(fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),

                    // Add Comment Bar
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentInputController,
                              decoration: const InputDecoration(
                                hintText: 'Viết bình luận...',
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onSubmitted: (text) {
                                if (text.trim().isNotEmpty) {
                                  community.addComment(post.id, text);
                                  _commentInputController.clear();
                                  setSheetState(() {});
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                            icon: const Icon(Icons.send_rounded, size: 20),
                            onPressed: () {
                              final text = _commentInputController.text.trim();
                              if (text.isNotEmpty) {
                                community.addComment(post.id, text);
                                _commentInputController.clear();
                                setSheetState(() {});
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = CommunityController.instance.posts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cộng Đồng Ẩm Thực'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Đăng bài', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openCreatePostDialog,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final post = posts[index];
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.dividerDark
                    : AppColors.dividerLight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author Header
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          post.author.name.substring(0, 1),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    post.author.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    post.author.role,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Vừa chia sẻ bí quyết nấu ăn',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Post Title & Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    post.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: Text(
                    post.content,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),

                // Tags
                if (post.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: Wrap(
                      spacing: 6,
                      children: post.tags.map((t) {
                        return Text(
                          '#$t',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 8),

                // Dish Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(0)),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.asset(
                      post.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
                    ),
                  ),
                ),

                // Action Bar (Likes & Comments)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      // Like button
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: post.isLiked ? AppColors.accent : AppColors.textSecondaryLight,
                        ),
                        icon: Icon(
                          post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: post.isLiked ? AppColors.accent : null,
                          size: 20,
                        ),
                        label: Text(
                          '${post.likesCount}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          setState(() {
                            CommunityController.instance.toggleLike(post.id);
                          });
                        },
                      ),
                      const SizedBox(width: 8),

                      // Comments button
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondaryLight,
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
                        label: Text(
                          '${post.comments.length} bình luận',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _openCommentsBottomSheet(post),
                      ),
                      const Spacer(),

                      IconButton(
                        icon: const Icon(Icons.bookmark_border_rounded, size: 20),
                        tooltip: 'Lưu bài viết',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã lưu bài viết vào mục yêu thích!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

