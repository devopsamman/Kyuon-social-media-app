import 'package:supabase_flutter/supabase_flutter.dart';

class SearchResult {
  final List<UserSearchResult> users;
  final List<PostSearchResult> posts;
  final List<ReelSearchResult> reels;

  SearchResult({required this.users, required this.posts, required this.reels});

  bool get isEmpty => users.isEmpty && posts.isEmpty && reels.isEmpty;
}

class UserSearchResult {
  final String id;
  final String username;
  final String? fullName;
  final String? profileImageUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;

  UserSearchResult({
    required this.id,
    required this.username,
    this.fullName,
    this.profileImageUrl,
    this.bio,
    required this.followersCount,
    required this.followingCount,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      bio: json['bio'] as String?,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
    );
  }
}

class PostSearchResult {
  final String id;
  final String userId;
  final String? content;
  final String imageUrl;
  final DateTime createdAt;
  final String username;
  final String? profileImageUrl;

  PostSearchResult({
    required this.id,
    required this.userId,
    this.content,
    required this.imageUrl,
    required this.createdAt,
    required this.username,
    this.profileImageUrl,
  });

  factory PostSearchResult.fromJson(Map<String, dynamic> json) {
    return PostSearchResult(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: json['username'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
    );
  }
}

class ReelSearchResult {
  final String id;
  final String uploaderId;
  final String? title;
  final String videoUrl;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final String username;
  final String? profileImageUrl;

  ReelSearchResult({
    required this.id,
    required this.uploaderId,
    this.title,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.createdAt,
    required this.username,
    this.profileImageUrl,
  });

  factory ReelSearchResult.fromJson(Map<String, dynamic> json) {
    return ReelSearchResult(
      id: json['id'] as String,
      uploaderId: json['uploader_id'] as String,
      title: json['title'] as String?,
      videoUrl: json['video_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: json['username'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
    );
  }
}

class SearchService {
  final _supabase = Supabase.instance.client;

  // Search all (users, posts, reels)
  Future<SearchResult> searchAll(String query) async {
    if (query.trim().isEmpty) {
      return SearchResult(users: [], posts: [], reels: []);
    }

    try {
      print('🔍 Searching for: "$query"');

      // Use parallel execution for better performance
      final results = await Future.wait([
        searchUsers(query, limit: 10),
        searchPosts(query, limit: 15),
        searchReels(query, limit: 15),
      ]);

      // Don't save to search history here - only when user submits

      return SearchResult(
        users: results[0] as List<UserSearchResult>,
        posts: results[1] as List<PostSearchResult>,
        reels: results[2] as List<ReelSearchResult>,
      );
    } catch (e) {
      print('❌ Search error: $e');
      return SearchResult(users: [], posts: [], reels: []);
    }
  }

  // Search users only
  Future<List<UserSearchResult>> searchUsers(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final response =
          await _supabase.rpc(
                'search_users',
                params: {'search_query': query, 'result_limit': limit},
              )
              as List;

      return response
          .map(
            (json) => UserSearchResult.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('❌ User search error: $e');
      return [];
    }
  }

  // Search posts only
  Future<List<PostSearchResult>> searchPosts(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      print('🔍 Searching posts for: "$query"');

      final response = await _supabase.rpc(
        'search_posts',
        params: {'search_query': query, 'result_limit': limit},
      );

      print('📊 Posts response type: ${response.runtimeType}');
      print('📊 Posts response: $response');

      if (response == null) {
        print('⚠️ Posts response is null');
        return [];
      }

      final list = response as List;
      print('✅ Found ${list.length} posts');

      return list
          .map(
            (json) => PostSearchResult.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e, stackTrace) {
      print('❌ Post search error: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Search reels only
  Future<List<ReelSearchResult>> searchReels(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      print('🔍 Searching reels for: "$query"');

      final response = await _supabase.rpc(
        'search_reels',
        params: {'search_query': query, 'result_limit': limit},
      );

      print('📊 Reels response type: ${response.runtimeType}');
      print('📊 Reels response: $response');

      if (response == null) {
        print('⚠️ Reels response is null');
        return [];
      }

      final list = response as List;
      print('✅ Found ${list.length} reels');

      return list
          .map(
            (json) => ReelSearchResult.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e, stackTrace) {
      print('❌ Reel search error: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Get search history
  Future<List<String>> getSearchHistory({int limit = 10}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('search_history')
          .select('search_query')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => item['search_query'] as String)
          .toSet() // Remove duplicates
          .toList();
    } catch (e) {
      print('❌ Error getting search history: $e');
      return [];
    }
  }

  // Clear search history
  Future<void> clearSearchHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('search_history').delete().eq('user_id', userId);

      print('✅ Search history cleared');
    } catch (e) {
      print('❌ Error clearing search history: $e');
    }
  }

  // Save search to history (call this when user submits search)
  Future<void> saveSearchHistory(String query, {String type = 'all'}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('search_history').insert({
        'user_id': userId,
        'search_query': query,
        'search_type': type,
      });

      print('✅ Saved to search history: "$query"');
    } catch (e) {
      print('❌ Error saving search history: $e');
    }
  }
}
