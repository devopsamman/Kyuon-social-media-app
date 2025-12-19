import 'package:flutter/foundation.dart';
import '../models/post_data.dart';
import '../models/story_data.dart';
import '../models/reel_data.dart';
import 'supabase_service.dart';

class ContentProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<PostData> _posts = [];
  List<StoryData> _stories = [
    StoryData(
      username: 'you',
      avatarUrl: 'https://i.pravatar.cc/150?img=68',
      isOwn: true,
    ),
  ];
  List<ReelData> _reels = [];
  Set<String> _likedReels = {};
  Set<String> _likedPosts = {};
  bool _isLoading = false;

  ContentProvider() {
    _loadData();
  }

  bool get isLoading => _isLoading;
  List<PostData> get posts => _posts;
  List<StoryData> get stories => _stories;
  List<ReelData> get reels => _reels;
  Set<String> get likedReels => _likedReels;
  Set<String> get likedPosts => _likedPosts;

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('Loading posts...');
      final posts = await _supabaseService.getPosts();
      print('Received ${posts.length} posts from service');
      _posts = posts;
      print('Loaded ${posts.length} posts into provider');

      // Load user's liked posts
      if (posts.isNotEmpty) {
        final postIds = posts.map((p) => p.id).toList();
        _likedPosts = await _supabaseService.getUserLikedPosts(postIds);
        print('User has liked ${_likedPosts.length} posts');
      }

      // Debug: Print first post details if available
      if (posts.isNotEmpty) {
        final firstPost = posts.first;
        print('First post ID: ${firstPost.id}');
        print('First post username: ${firstPost.username}');
        print(
          'First post body: ${firstPost.body.substring(0, firstPost.body.length > 50 ? 50 : firstPost.body.length)}...',
        );
        print('First post has image: ${firstPost.imageUrl != null}');
      } else {
        print('WARNING: No posts were loaded!');
      }

      print('Loading stories...');
      final stories = await _supabaseService.getStories();
      print('Fetched ${stories.length} stories from database');

      // Fetch current user's profile to get their actual photo
      final currentUser = await _supabaseService.getCurrentUserProfile();
      final userProfilePhoto =
          currentUser?['profile_image_url'] as String? ??
          'https://i.pravatar.cc/150?img=68';
      final userProfileName = currentUser?['username'] as String? ?? 'you';

      // Filter out stories without imageUrl for display
      final validStories =
          stories
              .where((s) => s.imageUrl != null && s.imageUrl!.isNotEmpty)
              .toList();
      print('Valid stories after filtering: ${validStories.length}');

      // Group stories by user - each user gets ONE circle
      final Map<String, List<StoryData>> groupedStories = {};
      final currentUserId = await _supabaseService.getCurrentUserId();

      for (var story in validStories) {
        // Get user identifier from story
        final userId = story.userId ?? story.username;

        if (!groupedStories.containsKey(userId)) {
          groupedStories[userId] = [];
        }
        groupedStories[userId]!.add(story);
      }

      // Create one story circle per user (excluding current user, we'll add them separately)
      final otherUsersStories =
          groupedStories.entries
              .where(
                (entry) =>
                    entry.key != currentUserId && entry.key != userProfileName,
              )
              .map((entry) {
                // Use the first story's data for the circle, but it represents all stories
                final firstStory = entry.value.first;
                return StoryData(
                  username: firstStory.username,
                  avatarUrl: firstStory.avatarUrl,
                  imageUrl: firstStory.imageUrl, // First story image
                  isOwn: false,
                  userId: firstStory.userId,
                  allStories: entry.value, // Store all stories for this user
                );
              })
              .toList();

      // Check if current user has any stories
      final myStories =
          groupedStories.entries
              .where(
                (entry) =>
                    entry.key == currentUserId || entry.key == userProfileName,
              )
              .expand((entry) => entry.value)
              .toList();

      // Update "Your story" with first story image if exists
      final myStoryWithData = StoryData(
        username: userProfileName,
        avatarUrl: userProfilePhoto,
        imageUrl: myStories.isNotEmpty ? myStories.first.imageUrl : null,
        isOwn: true,
        userId: currentUserId,
        allStories: myStories,
      );

      _stories = [myStoryWithData, ...otherUsersStories];
      print('Total story circles to display: ${_stories.length}');

      print('Loading reels...');
      final reels = await _supabaseService.getReels();
      _reels = reels;
      print('Loaded ${reels.length} reels');

      // Load user's liked reels
      if (reels.isNotEmpty) {
        final reelIds = reels.map((r) => r.id).toList();
        _likedReels = await _supabaseService.getUserLikedReels(reelIds);
        print('User has liked ${_likedReels.length} reels');
      }

      // Debug: Print first reel details if available
      if (reels.isNotEmpty) {
        final firstReel = reels.first;
        print('First reel username: ${firstReel.username}');
        print('First reel caption: ${firstReel.caption}');
        print('First reel video URL: ${firstReel.videoUrl}');
        print('First reel likes: ${firstReel.likes}');
        print('First reel comments: ${firstReel.comments}');
      } else {
        print('WARNING: No reels were loaded!');
      }
    } catch (e) {
      print('Error loading data: $e');
      print('Stack trace: ${StackTrace.current}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    print('Refreshing data...');
    await _loadData();
    print(
      'Data refresh complete. Posts: ${_posts.length}, Stories: ${_stories.length}, Reels: ${_reels.length}',
    );
  }

  Future<void> refreshReels() async {
    print('Refreshing reels only...');
    try {
      final reels = await _supabaseService.getReels();
      _reels = reels;
      print('Refreshed ${reels.length} reels');
      notifyListeners();
    } catch (e) {
      print('Error refreshing reels: $e');
    }
  }

  Future<void> addPost(PostData post) async {
    // Optimistic update
    _posts.insert(0, post);
    notifyListeners();

    try {
      await _supabaseService.createPost(post.body, post.imageUrl);
      // Ideally we would replace the optimistic post with the real one from DB
      // to get the correct ID and timestamp, but for now this is fine.
    } catch (e) {
      print('Failed to create post in Supabase: $e');
      // Rollback if needed
      _posts.remove(post);
      notifyListeners();
    }
  }

  Future<void> likePost(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      final updatedPost = PostData(
        id: post.id,
        username: post.username,
        avatarUrl: post.avatarUrl,
        timeAgo: post.timeAgo,
        body: post.body,
        imageUrl: post.imageUrl,
        likes: post.likes + 1,
        replies: post.replies,
      );
      _posts[index] = updatedPost;
      _likedPosts.add(postId);
      notifyListeners();

      try {
        await _supabaseService.likePost(postId);
      } catch (e) {
        print('Failed to like post: $e');
        // Revert
        _posts[index] = post;
        _likedPosts.remove(postId);
        notifyListeners();
      }
    }
  }

  Future<void> unlikePost(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      final updatedPost = PostData(
        id: post.id,
        username: post.username,
        avatarUrl: post.avatarUrl,
        timeAgo: post.timeAgo,
        body: post.body,
        imageUrl: post.imageUrl,
        likes: post.likes > 0 ? post.likes - 1 : 0,
        replies: post.replies,
      );
      _posts[index] = updatedPost;
      _likedPosts.remove(postId);
      notifyListeners();

      try {
        await _supabaseService.unlikePost(postId);
      } catch (e) {
        print('Failed to unlike post: $e');
        // Revert
        _posts[index] = post;
        _likedPosts.add(postId);
        notifyListeners();
      }
    }
  }

  Future<void> commentOnPost(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      // Optimistic update
      final updatedPost = PostData(
        id: post.id,
        username: post.username,
        avatarUrl: post.avatarUrl,
        timeAgo: post.timeAgo,
        body: post.body,
        imageUrl: post.imageUrl,
        likes: post.likes,
        replies: post.replies + 1,
      );
      _posts[index] = updatedPost;
      notifyListeners();

      try {
        await _supabaseService.commentOnPost(postId, post.replies);
      } catch (e) {
        print('Failed to comment: $e');
        _posts[index] = post;
        notifyListeners();
      }
    }
  }

  void addStory(StoryData story) {
    _stories.insert(1, story); // Insert after "you"
    notifyListeners();
  }

  void addReel(ReelData reel) {
    _reels.insert(0, reel);
    notifyListeners();
  }

  Future<void> likeReel(String reelId) async {
    final index = _reels.indexWhere((r) => r.id == reelId);
    if (index != -1) {
      final reel = _reels[index];
      final updatedReel = ReelData(
        id: reel.id,
        username: reel.username,
        caption: reel.caption,
        videoUrl: reel.videoUrl,
        avatarUrl: reel.avatarUrl,
        likes: reel.likes + 1,
        comments: reel.comments,
      );
      _reels[index] = updatedReel;
      _likedReels.add(reelId); // Mark as liked
      notifyListeners();

      try {
        await _supabaseService.likeReel(reelId);
      } catch (e) {
        print('Failed to like reel: $e');
        // Revert
        _reels[index] = reel;
        _likedReels.remove(reelId);
        notifyListeners();
      }
    }
  }

  Future<void> unlikeReel(String reelId) async {
    final index = _reels.indexWhere((r) => r.id == reelId);
    if (index != -1) {
      final reel = _reels[index];
      final updatedReel = ReelData(
        id: reel.id,
        username: reel.username,
        caption: reel.caption,
        videoUrl: reel.videoUrl,
        avatarUrl: reel.avatarUrl,
        likes: reel.likes > 0 ? reel.likes - 1 : 0,
        comments: reel.comments,
      );
      _reels[index] = updatedReel;
      _likedReels.remove(reelId);
      notifyListeners();

      try {
        await _supabaseService.unlikeReel(reelId);
      } catch (e) {
        print('Failed to unlike reel: $e');
        // Revert
        _reels[index] = reel;
        _likedReels.add(reelId);
        notifyListeners();
      }
    }
  }

  Future<void> commentOnReel(String reelId) async {
    final index = _reels.indexWhere((r) => r.id == reelId);
    if (index != -1) {
      final reel = _reels[index];
      // Optimistic update
      final updatedReel = ReelData(
        id: reel.id,
        username: reel.username,
        caption: reel.caption,
        videoUrl: reel.videoUrl,
        avatarUrl: reel.avatarUrl,
        likes: reel.likes,
        comments: reel.comments + 1,
      );
      _reels[index] = updatedReel;
      notifyListeners();

      try {
        await _supabaseService.commentOnReel(reelId, reel.comments);
      } catch (e) {
        print('Failed to comment on reel: $e');
        _reels[index] = reel;
        notifyListeners();
      }
    }
  }
}
