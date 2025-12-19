import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/post_data.dart';
import '../models/reel_data.dart';
import '../services/content_provider.dart';
import '../services/messaging_service.dart';
import 'user_posts_view.dart';
import 'user_reels_view.dart';
import 'chat_screen.dart';

// Screen to view other users' profiles
class OtherUserProfileScreen extends StatefulWidget {
  final String userId; // The user ID to display

  const OtherUserProfileScreen({super.key, required this.userId});

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isFollowing = false;
  Map<String, dynamic>? _profileData;
  List<PostData> _userPosts = [];
  List<ReelData> _userReels = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchProfile();
    _checkIfFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkIfFollowing() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final response =
          await Supabase.instance.client
              .from('followers')
              .select()
              .eq('follower_id', currentUser.id)
              .eq('following_id', widget.userId)
              .maybeSingle();

      if (mounted) {
        setState(() {
          _isFollowing = response != null;
        });
      }
    } catch (e) {
      print('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      print('🔄 Toggle follow for user: ${widget.userId}');
      print('Current state - isFollowing: $_isFollowing');

      if (_isFollowing) {
        // Unfollow
        print('📤 Unfollowing user...');
        await Supabase.instance.client
            .from('followers')
            .delete()
            .eq('follower_id', currentUser.id)
            .eq('following_id', widget.userId);
        print('✅ Unfollow successful');
      } else {
        // Follow
        print('📥 Following user...');
        await Supabase.instance.client.from('followers').insert({
          'follower_id': currentUser.id,
          'following_id': widget.userId,
        });
        print('✅ Follow successful');
      }

      // Verify database update
      final followCount =
          await Supabase.instance.client
              .from('followers')
              .select()
              .eq('follower_id', currentUser.id)
              .eq('following_id', widget.userId)
              .count();
      print(
        '📊 Database verification - Follow exists: ${followCount.count > 0}',
      );

      // Update local state
      setState(() {
        _isFollowing = !_isFollowing;
        if (_profileData != null) {
          _profileData!['followers_count'] =
              (_profileData!['followers_count'] ?? 0) + (_isFollowing ? 1 : -1);
        }
      });
      print('🔄 Updated local state - New isFollowing: $_isFollowing');

      // Refresh current user's profile to update following count
      final currentUserProfile =
          await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', currentUser.id)
              .single();
      print(
        '📈 Current user following count: ${currentUserProfile['following_count']}',
      );

      // Refresh provider data
      if (mounted) {
        Provider.of<ContentProvider>(context, listen: false).refreshData();
        print('✅ Provider data refreshed');
      }
    } catch (e) {
      print('❌ Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _fetchProfile() async {
    try {
      setState(() => _isLoading = true);
      print('📥 Fetching profile for user: ${widget.userId}');

      // Fetch user profile
      final profileResponse =
          await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', widget.userId)
              .single();

      _profileData = profileResponse;
      print('✅ Profile loaded: ${_profileData?['username']}');
      print(
        '📊 Followers: ${_profileData?['followers_count']}, Following: ${_profileData?['following_count']}',
      );

      // Fetch user's posts (without nested select)
      print('📥 Fetching user posts...');
      final postsResponse = await Supabase.instance.client
          .from('posts')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      // Fetch profile data for posts
      if (postsResponse.isNotEmpty) {
        final userIds = {widget.userId};
        final profilesResponse = await Supabase.instance.client
            .from('profiles')
            .select()
            .inFilter('id', userIds.toList());

        final profileMap = <String, Map<String, dynamic>>{
          for (var profile in (profilesResponse as List))
            profile['id'] as String: Map<String, dynamic>.from(profile as Map),
        };

        // Merge profile data into posts
        final postsWithProfiles =
            (postsResponse as List).map((post) {
              final profile = profileMap[post['user_id']];
              return <String, dynamic>{
                ...Map<String, dynamic>.from(post as Map),
                'profiles': profile,
              };
            }).toList();

        _userPosts =
            postsWithProfiles.map((json) => PostData.fromJson(json)).toList();
        print('✅ Loaded ${_userPosts.length} posts');
      }

      // Fetch user's reels (without nested select)
      print('📥 Fetching user reels...');
      final reelsResponse = await Supabase.instance.client
          .from('videos')
          .select()
          .eq('uploader_id', widget.userId)
          .order('created_at', ascending: false);

      // Fetch profile data for reels
      if (reelsResponse.isNotEmpty) {
        final userIds = {widget.userId};
        final profilesResponse = await Supabase.instance.client
            .from('profiles')
            .select()
            .inFilter('id', userIds.toList());

        final profileMap = <String, Map<String, dynamic>>{
          for (var profile in (profilesResponse as List))
            profile['id'] as String: Map<String, dynamic>.from(profile as Map),
        };

        // Merge profile data into reels
        final reelsWithProfiles =
            (reelsResponse as List).map((reel) {
              final profile = profileMap[reel['uploader_id']];
              return <String, dynamic>{
                ...Map<String, dynamic>.from(reel as Map),
                'profiles': profile,
              };
            }).toList();

        _userReels =
            reelsWithProfiles.map((json) => ReelData.fromJson(json)).toList();
        print('✅ Loaded ${_userReels.length} reels');
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error fetching profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  void _openChat() async {
    try {
      print('🔄 Opening chat with user: ${widget.userId}');

      // Get or create conversation
      final messagingService = MessagingService();
      final conversationId = await messagingService.getOrCreateConversation(
        widget.userId,
      );

      print('✅ Conversation ID: $conversationId');

      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  conversationId: conversationId,
                  otherUserId: widget.userId,
                  otherUserName: _profileData?['username'] ?? 'User',
                  otherUserAvatar: _profileData?['profile_image_url'] ?? '',
                ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error opening chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        title: Text(
          _profileData?['username'] ?? 'Profile',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder:
              (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(child: _buildProfileHeader(isDarkMode)),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: isDarkMode ? Colors.white : Colors.black,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: isDarkMode ? Colors.white : Colors.black,
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_on), text: 'Posts'),
                        Tab(icon: Icon(Icons.video_library), text: 'Reels'),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPostsGrid(isDarkMode),
              _buildReelsGrid(isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile picture and stats
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(
                  _profileData?['profile_image_url'] ??
                      'https://i.pravatar.cc/150',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      'Posts',
                      _userPosts.length.toString(),
                      isDarkMode,
                    ),
                    _buildStatColumn(
                      'Followers',
                      (_profileData?['followers_count'] ?? 0).toString(),
                      isDarkMode,
                    ),
                    _buildStatColumn(
                      'Following',
                      (_profileData?['following_count'] ?? 0).toString(),
                      isDarkMode,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name and bio
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profileData?['username'] ?? 'User',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                if (_profileData?['bio'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _profileData!['bio'],
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Follow and Share buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isFollowing
                            ? (isDarkMode ? Colors.grey[800] : Colors.grey[300])
                            : Theme.of(context).primaryColor,
                    foregroundColor:
                        _isFollowing
                            ? (isDarkMode ? Colors.white : Colors.black)
                            : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(_isFollowing ? 'Following' : 'Follow'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _openChat,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDarkMode ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Message'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String count, bool isDarkMode) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPostsGrid(bool isDarkMode) {
    if (_userPosts.isEmpty) {
      return Center(
        child: Text(
          'No posts yet',
          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        UserPostsView(posts: _userPosts, initialIndex: index),
              ),
            );
          },
          child:
              post.imageUrl != null
                  ? Image.network(post.imageUrl!, fit: BoxFit.cover)
                  : Container(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                    child: const Icon(Icons.article),
                  ),
        );
      },
    );
  }

  Widget _buildReelsGrid(bool isDarkMode) {
    if (_userReels.isEmpty) {
      return Center(
        child: Text(
          'No reels yet',
          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _userReels.length,
      itemBuilder: (context, index) {
        final reel = _userReels[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        UserReelsView(reels: _userReels, initialIndex: index),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                reel.thumbnailUrl.isNotEmpty
                    ? reel.thumbnailUrl
                    : 'https://via.placeholder.com/150',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                    child: Icon(
                      Icons.videocam,
                      color: isDarkMode ? Colors.white : Colors.grey,
                      size: 40,
                    ),
                  );
                },
              ),
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color:
          Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
