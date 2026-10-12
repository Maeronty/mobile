import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/post.dart';
import '../data/mock_data.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;

  AppState._internal() {
    _recipes = List.from(MockData.recipes);
    _favoriteIds = {1, 2, 4, 8}; // Initial favorites
    _pantryIngredients = ['Thịt bò', 'Bánh phở', 'Hành hoa & ngò gai', 'Tỏi', 'Gừng'];
    _communityPosts = List.from(MockData.communityPosts);
    _currentUser = MockData.currentUser;
  }

  late List<Recipe> _recipes;
  late Set<int> _favoriteIds;
  late List<String> _pantryIngredients;
  late List<CommunityPost> _communityPosts;
  late UserProfile _currentUser;
  bool _isDarkMode = false;

  // Getters
  List<Recipe> get recipes => _recipes;
  Set<int> get favoriteIds => _favoriteIds;
  List<String> get pantryIngredients => _pantryIngredients;
  List<CommunityPost> get communityPosts => _communityPosts;
  UserProfile get currentUser => _currentUser;
  bool get isDarkMode => _isDarkMode;

  List<Recipe> get favoriteRecipes {
    return _recipes.where((r) => _favoriteIds.contains(r.id)).toList();
  }

  // Theme
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // Favorite toggle
  void toggleFavorite(int recipeId) {
    if (_favoriteIds.contains(recipeId)) {
      _favoriteIds.remove(recipeId);
    } else {
      _favoriteIds.add(recipeId);
    }
    notifyListeners();
  }

  bool isFavorite(int recipeId) => _favoriteIds.contains(recipeId);

  // Pantry management (Kitchen Bag)
  void addPantryIngredient(String ingredient) {
    final clean = ingredient.trim();
    if (clean.isNotEmpty && !_pantryIngredients.contains(clean)) {
      _pantryIngredients.add(clean);
      notifyListeners();
    }
  }

  void removePantryIngredient(String ingredient) {
    _pantryIngredients.remove(ingredient);
    notifyListeners();
  }

  void clearPantry() {
    _pantryIngredients.clear();
    notifyListeners();
  }

  // Smart Recipe Suggestion Algorithm
  List<Recipe> matchRecipesByIngredients(List<String> searchIngredients) {
    if (searchIngredients.isEmpty) return _recipes;

    final lowerInputs = searchIngredients.map((e) => e.toLowerCase().trim()).toList();
    final List<Recipe> scoredList = [];

    for (final recipe in _recipes) {
      final List<String> matched = [];
      final List<String> missing = [];

      for (final ing in recipe.ingredients) {
        final ingNameLower = ing.name.toLowerCase();
        final isHit = lowerInputs.any((userIng) =>
            ingNameLower.contains(userIng) || userIng.contains(ingNameLower));

        if (isHit) {
          matched.add(ing.name);
        } else {
          missing.add(ing.name);
        }
      }

      final total = recipe.ingredients.length;
      final matchCount = matched.length;
      final score = total > 0 ? (matchCount / total) : 0.0;

      // Include recipes that have at least 1 match or if score > 0
      if (matchCount > 0) {
        scoredList.add(recipe.copyWith(
          matchScore: score,
          matchedIngredients: matched,
          missingIngredients: missing,
        ));
      }
    }

    // Sort by match score descending
    scoredList.sort((a, b) => (b.matchScore ?? 0).compareTo(a.matchScore ?? 0));
    return scoredList;
  }

  // Community actions
  void toggleLikePost(String postId) {
    final idx = _communityPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final post = _communityPosts[idx];
      final newIsLiked = !post.isLiked;
      final newLikes = newIsLiked ? post.likesCount + 1 : post.likesCount - 1;

      _communityPosts[idx] = post.copyWith(
        isLiked: newIsLiked,
        likesCount: newLikes < 0 ? 0 : newLikes,
      );
      notifyListeners();
    }
  }

  void addComment(String postId, String commentContent) {
    if (commentContent.trim().isEmpty) return;

    final idx = _communityPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final post = _communityPosts[idx];
      final newComment = PostComment(
        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
        userName: _currentUser.name,
        userAvatar: _currentUser.avatarUrl,
        userRole: _currentUser.role,
        content: commentContent.trim(),
        createdAt: DateTime.now(),
        likesCount: 0,
        isLiked: false,
        isAuthor: false,
      );

      final updatedComments = List<PostComment>.from(post.comments)..add(newComment);
      _communityPosts[idx] = post.copyWith(comments: updatedComments);
      notifyListeners();
    }
  }

  void createPost({
    required String title,
    required String content,
    required String imageAsset,
    required List<String> tags,
  }) {
    final newPost = CommunityPost(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      author: _currentUser,
      title: title,
      content: content,
      imageAsset: imageAsset.isNotEmpty ? imageAsset : 'assets/images/pho.png',
      tags: tags,
      createdAt: DateTime.now(),
      likesCount: 1,
      isLiked: true,
      comments: [],
    );

    _communityPosts.insert(0, newPost);
    notifyListeners();
  }
}
