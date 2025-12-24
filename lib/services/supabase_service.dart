import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_data.dart';
import '../models/story_data.dart';
import '../models/reel_data.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  static String? _guestUserId;
  static String? _guestUsername;

  // Generate a valid UUID v4 for guest user
  String _generateUUID() {
    final random = Random();
    final chars = '0123456789abcdef';

    // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    // where y is one of 8, 9, a, or b
    String generateHex(int length) {
      return List.generate(
        length,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
    }

    final part1 = generateHex(8);
    final part2 = generateHex(4);
    final part3 = '4${generateHex(3)}'; // Version 4
    final part4 = '${['8', '9', 'a', 'b'][random.nextInt(4)]}${generateHex(3)}';
    final part5 = generateHex(12);

    return '$part1-$part2-$part3-$part4-$part5';
  }

  // Generate a persistent guest user ID (valid UUID format)
  String _getGuestUserId() {
    if (_guestUserId == null) {
      // Generate a valid UUID v4 for guest user
      _guestUserId = _generateUUID();
      // Generate a simple username from the UUID
      _guestUsername = 'Guest_${_guestUserId!.substring(0, 8)}';
      print('Generated guest user ID (UUID): $_guestUserId');
      print('Generated guest username: $_guestUsername');
    }
    return _guestUserId!;
  }

  String _getGuestUsername() {
    if (_guestUsername == null) {
      _getGuestUserId(); // This will set _guestUsername
    }
    return _guestUsername ?? 'Guest';
  }

  Future<List<PostData>> getPosts() async {
    try {
      print('Starting to fetch posts...');

      // Fetch posts and profiles separately (join doesn't work because FK points to auth.users)
      final postsResponse = await _client
          .from('posts')
          .select()
          .order('created_at', ascending: false);

      print('Fetched ${(postsResponse as List).length} posts from Supabase');

      if ((postsResponse as List).isEmpty) {
        print('No posts found in database');
        return [];
      }

      // Get unique user IDs from posts
      final userIds =
          (postsResponse as List)
              .map((p) => p['user_id']?.toString())
              .whereType<String>()
              .toSet()
              .toList();

      print('Found ${userIds.length} unique user IDs');

      // Fetch all profiles
      List<Map<String, dynamic>> profilesResponse = [];
      if (userIds.isNotEmpty) {
        try {
          final allProfiles = await _client
              .from('profiles')
              .select('id, username, profile_image_url');

          profilesResponse =
              (allProfiles as List)
                  .where((p) => userIds.contains(p['id']?.toString()))
                  .cast<Map<String, dynamic>>()
                  .toList();

          print('Fetched ${profilesResponse.length} profiles');
        } catch (e) {
          print('Error fetching profiles: $e');
          // Continue without profiles - will use defaults
        }
      }

      // Create a map of user_id -> profile
      final profilesMap = <String, Map<String, dynamic>>{
        for (var profile in profilesResponse)
          profile['id']?.toString() ?? '': profile,
      };

      print('Created profiles map with ${profilesMap.length} entries');

      // Combine posts with profiles
      final posts =
          (postsResponse as List)
              .map((postJson) {
                try {
                  final userId = postJson['user_id']?.toString() ?? '';
                  final profile = profilesMap[userId] ?? <String, dynamic>{};

                  // Create combined JSON
                  final combinedJson = Map<String, dynamic>.from(postJson);
                  combinedJson['profiles'] = profile;

                  final post = PostData.fromJson(combinedJson);
                  print('Parsed post: ${post.id} - ${post.username}');
                  return post;
                } catch (e, stackTrace) {
                  print('Error parsing post: $e');
                  print('Stack trace: $stackTrace');
                  print('Post JSON: $postJson');
                  return null;
                }
              })
              .whereType<PostData>()
              .toList();

      print(
        'Successfully parsed ${posts.length} posts out of ${(postsResponse as List).length}',
      );
      return posts;
    } catch (e, stackTrace) {
      print('Error fetching posts: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<StoryData>> getStories() async {
    try {
      // Calculate the timestamp for 24 hours ago
      final twentyFourHoursAgo = DateTime.now().subtract(
        const Duration(hours: 24),
      );

      final response = await _client
          .from('stories')
          .select('*') // No join needed as user_name/avatar are in table
          .gte(
            'created_at',
            twentyFourHoursAgo.toIso8601String(),
          ) // Only fetch stories from last 24 hours
          .order('created_at', ascending: false);

      print('Fetched ${(response as List).length} stories (last 24 hours)');
      final currentUserId = _client.auth.currentUser?.id;

      return (response as List).map((json) {
        final userId = json['user_id'];
        return StoryData.fromJson(json, isOwn: userId == currentUserId);
      }).toList();
    } catch (e) {
      print('Error fetching stories: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  Future<List<ReelData>> getReels() async {
    try {
      print('Starting to fetch reels...');

      // Fetch videos and profiles separately (FK points to auth.users, not profiles)
      final videosResponse = await _client
          .from('videos')
          .select()
          .order('created_at', ascending: false);

      print('Fetched ${(videosResponse as List).length} videos from Supabase');

      if ((videosResponse as List).isEmpty) {
        print('No videos found in database');
        return [];
      }

      // Get unique uploader IDs
      final uploaderIds =
          (videosResponse as List)
              .map((v) => v['uploader_id']?.toString())
              .whereType<String>()
              .toSet()
              .toList();

      print('Found ${uploaderIds.length} unique uploader IDs');

      // Fetch all profiles
      List<Map<String, dynamic>> profilesResponse = [];
      if (uploaderIds.isNotEmpty) {
        try {
          final allProfiles = await _client
              .from('profiles')
              .select('id, username, profile_image_url');

          profilesResponse =
              (allProfiles as List)
                  .where((p) => uploaderIds.contains(p['id']?.toString()))
                  .cast<Map<String, dynamic>>()
                  .toList();

          print('Fetched ${profilesResponse.length} profiles');
        } catch (e) {
          print('Error fetching profiles: $e');
          // Continue without profiles - will use defaults
        }
      }

      // Create a map of uploader_id -> profile
      final profilesMap = <String, Map<String, dynamic>>{
        for (var profile in profilesResponse)
          profile['id']?.toString() ?? '': profile,
      };

      print('Created profiles map with ${profilesMap.length} entries');

      // Combine videos with profiles
      final reels =
          (videosResponse as List)
              .map((videoJson) {
                try {
                  final uploaderId = videoJson['uploader_id']?.toString() ?? '';
                  final profile =
                      profilesMap[uploaderId] ?? <String, dynamic>{};

                  // Create combined JSON
                  final combinedJson = Map<String, dynamic>.from(videoJson);
                  combinedJson['profiles'] = profile;

                  final reel = ReelData.fromJson(combinedJson);
                  print('Parsed reel: ${reel.videoUrl} - ${reel.username}');
                  return reel;
                } catch (e, stackTrace) {
                  print('Error parsing reel: $e');
                  print('Stack trace: $stackTrace');
                  print('Video JSON: $videoJson');
                  return null;
                }
              })
              .whereType<ReelData>()
              .toList();

      print(
        'Successfully parsed ${reels.length} reels out of ${(videosResponse as List).length}',
      );
      return reels;
    } catch (e, stackTrace) {
      print('Error fetching reels: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<void> likePost(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to like posts');
    }

    try {
      // Insert like into post_likes table
      // Database trigger will automatically update posts.likes count
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': user.id,
      });
    } catch (e) {
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('unique constraint')) {
        print('User already liked this post');
        return;
      }
      rethrow;
    }
  }

  Future<void> unlikePost(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to unlike posts');
    }

    try {
      // Delete like from post_likes table
      // Database trigger will automatically update posts.likes count
      await _client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', user.id);
    } catch (e) {
      print('Error unliking post: $e');
      rethrow;
    }
  }

  Future<bool> hasUserLikedPost(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final result =
          await _client
              .from('post_likes')
              .select()
              .eq('post_id', postId)
              .eq('user_id', user.id)
              .maybeSingle();

      return result != null;
    } catch (e) {
      print('Error checking if user liked post: $e');
      return false;
    }
  }

  Future<Set<String>> getUserLikedPosts(List<String> postIds) async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    if (postIds.isEmpty) return {};

    try {
      final result = await _client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', user.id)
          .filter('post_id', 'in', '(${postIds.join(',')})');

      return (result as List)
          .map((item) => item['post_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (e) {
      print('Error getting user liked posts: $e');
      return {};
    }
  }

  Future<void> commentOnPost(String postId, int currentComments) async {
    await _client
        .from('posts')
        .update({'comments': currentComments + 1})
        .eq('id', postId);
  }

  Future<void> likeReel(String reelId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to like reels');
    }

    try {
      // Insert like into video_likes table
      // Database trigger will automatically update videos.likes count
      await _client.from('video_likes').insert({
        'video_id': reelId,
        'user_id': user.id,
      });
    } catch (e) {
      // If the error is about duplicate key, the user already liked this
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('unique constraint')) {
        print('User already liked this reel');
        return; // Silently ignore
      }
      rethrow;
    }
  }

  Future<void> unlikeReel(String reelId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to unlike reels');
    }

    try {
      // Delete like from video_likes table
      // Database trigger will automatically update videos.likes count
      await _client
          .from('video_likes')
          .delete()
          .eq('video_id', reelId)
          .eq('user_id', user.id);
    } catch (e) {
      print('Error unliking reel: $e');
      rethrow;
    }
  }

  Future<bool> hasUserLikedReel(String reelId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final result =
          await _client
              .from('video_likes')
              .select()
              .eq('video_id', reelId)
              .eq('user_id', user.id)
              .maybeSingle();

      return result != null;
    } catch (e) {
      print('Error checking if user liked reel: $e');
      return false;
    }
  }

  Future<Set<String>> getUserLikedReels(List<String> reelIds) async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    if (reelIds.isEmpty) return {};

    try {
      final result = await _client
          .from('video_likes')
          .select('video_id')
          .eq('user_id', user.id)
          .filter('video_id', 'in', '(${reelIds.join(',')})');

      return (result as List)
          .map((item) => item['video_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (e) {
      print('Error getting user liked reels: $e');
      return {};
    }
  }

  Future<void> commentOnReel(String reelId, int currentComments) async {
    await _client
        .from('videos')
        .update({'comments': currentComments + 1})
        .eq('id', reelId);
  }

  Future<void> createPost(String body, String? imageUrl) async {
    print('createPost: Starting post creation...');

    // Get authenticated user
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to create posts');
    }
    final userId = user.id;

    // Validate that image URL is from Cloudinary if provided
    if (imageUrl != null && !imageUrl.contains('cloudinary.com')) {
      throw Exception('Post images must be uploaded to Cloudinary');
    }

    print('createPost: Creating post for user: $userId');
    await _client.from('posts').insert({
      'user_id': userId,
      'content': body,
      'image_url': imageUrl,
    });
    print('createPost: Post created successfully');
  }

  Future<void> createStory(String imageUrl) async {
    print('createStory: Starting story creation...');
    print('createStory: Image URL: $imageUrl');

    try {
      // Get authenticated user
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to create stories');
      }
      final userId = user.id;
      print('createStory: Using user ID: $userId');

      // Validate that image URL is from Cloudinary
      if (!imageUrl.contains('cloudinary.com')) {
        throw Exception('Story images must be uploaded to Cloudinary');
      }

      // Ensure profile exists
      print('createStory: Ensuring profile exists...');
      await _ensureProfileExists(userId);

      // Fetch user profile to get name/avatar for denormalized fields
      print('createStory: Fetching user profile...');
      Map<String, dynamic> profile;
      try {
        final profileResponse =
            await _client
                .from('profiles')
                .select()
                .eq('id', userId)
                .maybeSingle();

        if (profileResponse != null) {
          profile = Map<String, dynamic>.from(profileResponse);
          print(
            'createStory: Profile fetched. Username: ${profile['username']}',
          );
        } else {
          throw Exception('Profile not found');
        }
      } catch (e) {
        print('createStory: Could not fetch profile, using defaults: $e');
        // Use default values if profile fetch fails
        profile = {
          'username': _getGuestUsername(),
          'profile_image_url': 'https://i.pravatar.cc/150?img=68',
        };
      }

      print('createStory: Creating story in database...');

      final storyData = {
        'user_id': userId,
        'user_name': profile['username']?.toString() ?? _getGuestUsername(),
        'user_avatar':
            profile['profile_image_url']?.toString() ??
            'https://i.pravatar.cc/150?img=68',
        'image_url': imageUrl,
      };

      print('createStory: Story data: $storyData');

      await _client.from('stories').insert(storyData);
      print('createStory: Story created successfully!');
    } catch (e, stackTrace) {
      print('createStory: ERROR - $e');
      print('createStory: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> createReel(String videoUrl, String caption) async {
    print('createReel: Starting reel creation...');

    // Get authenticated user
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to create reels');
    }
    final userId = user.id;

    // Validate that video URL is from Cloudinary
    if (!videoUrl.contains('cloudinary.com')) {
      throw Exception('Videos must be uploaded to Cloudinary');
    }

    // Generate thumbnail URL from video URL
    // Cloudinary allows getting video thumbnail by modifying the URL
    String thumbnailUrl = videoUrl
        .replaceAll('/upload/', '/upload/so_0,f_jpg/')
        .replaceAll('.mp4', '.jpg');

    print('createReel: Creating reel for user: $userId');
    print('createReel: Video URL: $videoUrl');
    print('createReel: Generated thumbnail URL: $thumbnailUrl');

    await _client.from('videos').insert({
      'uploader_id': userId,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl, // Add generated thumbnail
      'title': caption, // Mapping caption to title as 'videos' table has title
      'description': caption,
    });
    print('createReel: Reel created successfully');
  }

  Future<void> signInAnonymously() async {
    // Guest user system - no authentication needed
    print('signInAnonymously: Using guest user system (no auth required)');
    final guestUserId = _getGuestUserId();
    print('signInAnonymously: Guest user ID: $guestUserId');

    // Ensure profile exists for guest user
    try {
      await _ensureProfileExists(guestUserId);
    } catch (e) {
      print('signInAnonymously: Error ensuring profile exists: $e');
      // Don't throw - profile creation is not critical
    }
  }

  // Get current user ID (guest or authenticated)
  String? getCurrentUserId() {
    final session = _client.auth.currentSession;
    if (session != null) {
      return session.user.id;
    }
    return _getGuestUserId();
  }

  Future<void> _ensureProfileExists(String userId) async {
    try {
      print('_ensureProfileExists: Checking profile for user: $userId');
      // Check if profile exists
      final existing =
          await _client
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();

      if (existing == null) {
        print('_ensureProfileExists: Profile does not exist, creating...');
        // Create profile for guest user
        // Generate username from UUID (first 8 chars)
        final username = 'Guest_${userId.substring(0, 8)}';

        print(
          '_ensureProfileExists: Inserting profile with ID: $userId, username: $username',
        );
        await _client.from('profiles').insert({
          'id': userId,
          'username': username,
          'profile_image_url': 'https://i.pravatar.cc/150?img=68',
        });
        print(
          '_ensureProfileExists: Created profile for user: $userId with username: $username',
        );
      } else {
        print('_ensureProfileExists: Profile already exists for user: $userId');
      }
    } catch (e, stackTrace) {
      print('_ensureProfileExists: Error ensuring profile exists: $e');
      print('_ensureProfileExists: Stack trace: $stackTrace');
      // Don't throw - profile creation is not critical, but log it
    }
  }

  Future<void> _ensureAuthenticated() async {
    print('_ensureAuthenticated: Using guest user system (no auth required)');
    // Use guest user system - no authentication needed
    await signInAnonymously();
    print('_ensureAuthenticated: Guest user ready');
  }

  // Get user ID for current operation (guest or authenticated)
  String _getUserId() {
    final session = _client.auth.currentSession;
    if (session != null) {
      return session.user.id;
    }
    return _getGuestUserId();
  }

  // Check if username is available
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final response =
          await _client
              .from('profiles')
              .select('id')
              .eq('username', username.toLowerCase().trim())
              .maybeSingle();

      // If no result found, username is available
      return response == null;
    } catch (e) {
      print('Error checking username availability: $e');
      return false; // On error, assume not available to be safe
    }
  }

  // Create user profile after authentication
  Future<void> createUserProfile({
    required String userId,
    required String username,
    String? bio,
    String? profileImageUrl,
    String? phone,
    String? email,
    String? firstName,
    String? lastName,
    String? referralId,
    String? gender,
  }) async {
    try {
      print('createUserProfile: Creating profile for user: $userId');

      // Check if profile already exists
      final existing =
          await _client
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();

      final profileData = {
        'username': username.toLowerCase().trim(),
        'bio': bio,
        'profile_image_url':
            profileImageUrl ?? 'https://i.pravatar.cc/150?img=68',
        'phone': phone,
        if (email != null) 'email': email,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (firstName != null && lastName != null)
          'full_name': '$firstName $lastName',
        if (gender != null) 'gender': gender,
      };

      if (existing != null) {
        print('createUserProfile: Profile already exists, updating...');
        // Update existing profile
        await _client.from('profiles').update(profileData).eq('id', userId);
      } else {
        // Create new profile
        await _client.from('profiles').insert({'id': userId, ...profileData});
      }

      // Store referral ID if provided (you might want a separate referrals table)
      if (referralId != null && referralId.isNotEmpty) {
        print('createUserProfile: Referral ID: $referralId');
        // You can store referral in a separate table or as metadata
        // For now, we'll just log it
      }

      print('createUserProfile: Profile created/updated successfully');
    } catch (e, stackTrace) {
      print('createUserProfile: ERROR - $e');
      print('createUserProfile: Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Check if user has completed profile setup
  /// Get current user's profile data
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        print('No authenticated user');
        return null;
      }

      final profile =
          await _client
              .from('profiles')
              .select('id, username, profile_image_url')
              .eq('id', currentUser.id)
              .maybeSingle();

      return profile;
    } catch (e) {
      print('Error fetching current user profile: $e');
      return null;
    }
  }

  Future<bool> hasCompletedProfile(String userId) async {
    try {
      final profile =
          await _client
              .from('profiles')
              .select('username')
              .eq('id', userId)
              .maybeSingle();

      if (profile == null) {
        return false;
      }

      // Check if username is set (not null and not empty)
      final username = profile['username'];
      return username != null && username.toString().isNotEmpty;
    } catch (e) {
      print('Error checking profile completion: $e');
      return false;
    }
  }
}
