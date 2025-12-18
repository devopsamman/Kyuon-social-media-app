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
  bool _isLoading = false;

  ContentProvider() {
    _loadData();
  }

  bool get isLoading => _isLoading;
  List<PostData> get posts => _posts;
  List<StoryData> get stories => _stories;
  List<ReelData> get reels => _reels;

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('Loading posts...');
      final posts = await _supabaseService.getPosts();
      print('Received ${posts.length} posts from service');
      _posts = posts;
      print('Loaded ${posts.length} posts into provider');
      
      // Debug: Print first post details if available
      if (posts.isNotEmpty) {
        final firstPost = posts.first;
        print('First post ID: ${firstPost.id}');
        print('First post username: ${firstPost.username}');
        print('First post body: ${firstPost.body.substring(0, firstPost.body.length > 50 ? 50 : firstPost.body.length)}...');
        print('First post has image: ${firstPost.imageUrl != null}');
      } else {
        print('WARNING: No posts were loaded!');
      }

      print('Loading stories...');
      final stories = await _supabaseService.getStories();
      print('Fetched ${stories.length} stories from database');
      // Keep the "you" story at the beginning
      final myStory = _stories.firstWhere(
        (s) => s.isOwn,
        orElse:
            () => StoryData(
              username: 'you',
              avatarUrl: 'https://i.pravatar.cc/150?img=68',
              isOwn: true,
            ),
      );
      // Filter out stories without imageUrl for display
      final validStories = stories.where((s) => s.imageUrl != null && s.imageUrl!.isNotEmpty).toList();
      print('Valid stories after filtering: ${validStories.length}');
      _stories = [myStory, ...validStories];
      print('Total stories to display: ${_stories.length}');

      print('Loading reels...');
      final reels = await _supabaseService.getReels();
      _reels = reels;
      print('Loaded ${reels.length} reels');
      
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
    print('Data refresh complete. Posts: ${_posts.length}, Stories: ${_stories.length}, Reels: ${_reels.length}');
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
      notifyListeners();

      try {
        await _supabaseService.likePost(postId, post.likes);
      } catch (e) {
        print('Failed to like post: $e');
        // Revert
        _posts[index] = post;
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
}
