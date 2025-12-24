import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/post_data.dart';
import '../models/reel_data.dart';
import '../providers/theme_provider.dart';
import '../services/content_provider.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'user_posts_view.dart';
import 'user_reels_view.dart';
import 'followers_list_screen.dart';
import '../widgets/skeleton.dart';

// Helper function to generate thumbnail from Cloudinary video URL
String _generateThumbnailUrl(String videoUrl, String? thumbnailUrl) {
  // If thumbnail exists and is not empty, use it
  if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
    return thumbnailUrl;
  }

  // Generate thumbnail from Cloudinary video URL
  if (videoUrl.contains('cloudinary.com')) {
    // Replace /upload/ with /upload/so_0,f_jpg/ to get first frame as JPEG
    String thumbnail = videoUrl.replaceAll('/upload/', '/upload/so_0,f_jpg/');
    // Change extension from .mp4 to .jpg
    thumbnail = thumbnail.replaceAll('.mp4', '.jpg');
    return thumbnail;
  }

  // Fallback to placeholder
  return 'https://via.placeholder.com/150';
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<PostData> _userPosts = [];
  List<ReelData> _userReels = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh profile when returning from other screens
    // This ensures following count updates after following someone
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchProfile();
      }
    });
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // Handle unauthenticated state
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Fetch profile data
      final profileResponse =
          await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

      // Fetch posts without join - just get the post data
      final postsResponse = await Supabase.instance.client
          .from('posts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // Add profile data to each post manually
      final postsWithProfile =
          (postsResponse as List).map((postJson) {
            postJson['profiles'] = {
              'username': profileResponse?['username'] ?? 'Unknown',
              'profile_image_url': profileResponse?['profile_image_url'] ?? '',
            };
            return postJson;
          }).toList();

      // Fetch user's reels
      final reelsResponse = await Supabase.instance.client
          .from('videos')
          .select()
          .eq('uploader_id', user.id)
          .order('created_at', ascending: false);

      // Add profile data to each reel
      final reelsWithProfile =
          (reelsResponse as List).map((reelJson) {
            reelJson['profiles'] = {
              'username': profileResponse?['username'] ?? 'Unknown',
              'profile_image_url': profileResponse?['profile_image_url'] ?? '',
            };
            return reelJson;
          }).toList();

      setState(() {
        _profileData = profileResponse;
        _userPosts =
            postsWithProfile.map((json) => PostData.fromJson(json)).toList();
        _userReels =
            reelsWithProfile.map((json) => ReelData.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching profile: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showThemeDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Choose Theme'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Light Mode'),
                  value: ThemeMode.light,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setThemeMode(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark Mode'),
                  value: ThemeMode.dark,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setThemeMode(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('System Default'),
                  value: ThemeMode.system,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setThemeMode(value);
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show skeleton if loading AND we don't have profile data yet
    // This prevents showing skeleton on subsequent navigations
    if (_isLoading && _profileData == null) {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        body: SafeArea(child: const ProfileSkeleton()),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          'Please sign in to view profile',
          style: TextStyle(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
          ),
        ),
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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'theme') {
                _showThemeDialog(context);
              } else if (value == 'logout') {
                // Sign out from Supabase
                await Supabase.instance.client.auth.signOut();

                // Navigate to login screen
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'theme',
                    child: Row(
                      children: [
                        Icon(Icons.brightness_6, color: Colors.black),
                        SizedBox(width: 8),
                        Text('Theme Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.black),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) {
            return [
              SliverList(
                delegate: SliverChildListDelegate([_buildProfileHeader()]),
              ),
            ];
          },
          body: Column(
            children: [
              const TabBar(
                indicatorColor: Colors.blue,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(icon: Icon(Icons.grid_on)),
                  Tab(icon: Icon(Icons.video_library)),
                  Tab(icon: Icon(Icons.person_pin_outlined)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPostsGrid(),
                    _buildReelsGrid(),
                    const Center(
                      child: Text(
                        'Tagged Posts',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor:
                    isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                backgroundImage:
                    (_profileData?['profile_image_url'] != null &&
                            _profileData?['profile_image_url'] != '')
                        ? NetworkImage(_profileData!['profile_image_url'])
                        : null,
                child:
                    (_profileData?['profile_image_url'] == null ||
                            _profileData?['profile_image_url'] == '')
                        ? Icon(
                          Icons.person,
                          size: 40,
                          color:
                              isDarkMode
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400,
                        )
                        : null,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(
                      'Posts',
                      (_userPosts.length + _userReels.length).toString(),
                    ),
                    GestureDetector(
                      onTap: () {
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => FollowersListScreen(
                                    userId: user.id,
                                    isFollowersList: true,
                                    isOwnProfile: true,
                                  ),
                            ),
                          ).then(
                            (_) => _fetchProfile(),
                          ); // Refresh after returning
                        }
                      },
                      child: _buildStatColumn(
                        'Followers',
                        (_profileData?['followers_count'] ?? 0).toString(),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => FollowersListScreen(
                                    userId: user.id,
                                    isFollowersList: false,
                                    isOwnProfile: true,
                                  ),
                            ),
                          ).then(
                            (_) => _fetchProfile(),
                          ); // Refresh after returning
                        }
                      },
                      child: _buildStatColumn(
                        'Following',
                        (_profileData?['following_count'] ?? 0).toString(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _profileData?['full_name'] ?? _profileData?['username'] ?? 'User',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _profileData?['bio'] ?? 'No bio yet.',
            style: TextStyle(
              color: isDarkMode ? Colors.grey : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => EditProfileScreen(
                              profileData: _profileData ?? {},
                            ),
                      ),
                    );
                    // Refresh profile if edited
                    if (result == true) {
                      _fetchProfile();
                      // Also refresh ContentProvider to update story circle on home feed
                      if (mounted) {
                        await Provider.of<ContentProvider>(
                          context,
                          listen: false,
                        ).refreshData();
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDarkMode ? Colors.grey : Colors.grey.shade400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDarkMode ? Colors.grey : Colors.grey.shade400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Share Profile',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isDarkMode ? Colors.grey : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildPostsGrid() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      padding: EdgeInsets.zero,
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
            // Navigate to full post view starting at this index
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        UserPostsView(posts: _userPosts, initialIndex: index),
              ),
            );
          },
          child: Image.network(
            post.imageUrl ?? 'https://via.placeholder.com/150',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                child: Icon(
                  Icons.broken_image,
                  color: isDarkMode ? Colors.white : Colors.grey,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildReelsGrid() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_userReels.isEmpty) {
      return Center(
        child: Text(
          'No reels yet',
          style: TextStyle(
            color: isDarkMode ? Colors.grey : Colors.grey.shade700,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
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
            // Navigate to full reel view starting at this index
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
                _generateThumbnailUrl(reel.videoUrl, reel.thumbnailUrl),
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
              // Play icon overlay to indicate it's a video
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white.withOpacity(0.9),
                  size: 24,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black.withOpacity(0.5)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
