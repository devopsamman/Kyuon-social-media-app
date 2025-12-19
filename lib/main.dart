import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'models/post_data.dart';
import 'models/story_data.dart';
import 'models/reel_data.dart';
import 'services/content_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/create_post_screen.dart';
import 'screens/create_story_screen.dart';
import 'screens/story_viewer_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/comments_screen.dart';
import 'services/supabase_service.dart';
import 'widgets/skeleton.dart';
import 'screens/other_user_profile_screen.dart';
import 'screens/messages_screen.dart';
import 'services/messaging_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xzackrzudcmruzrhgjnl.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6YWNrcnp1ZGNtcnV6cmhnam5sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEwMDk0MjksImV4cCI6MjA3NjU4NTQyOX0.FO0pRwXqaB-q7gMC8XfbHjXYm88pK2ob9NeTXQ8pt3Q',
  );

  print('App initialized');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ContentProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'kyuonapp',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.white,
              textTheme: GoogleFonts.dmSansTextTheme(),
              useMaterial3: true,
              colorScheme: ColorScheme.light(
                primary: Colors.black,
                secondary: Colors.grey.shade800,
                surface: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: Colors.black,
                unselectedItemColor: Colors.grey,
                elevation: 8,
                type: BottomNavigationBarType.fixed,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121212),
              textTheme: GoogleFonts.dmSansTextTheme(
                ThemeData.dark().textTheme,
              ),
              useMaterial3: true,
              colorScheme: ColorScheme.dark(
                primary: Colors.white,
                secondary: Colors.grey.shade400,
                surface: const Color(0xFF1E1E1E),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: const Color(0xFF1E1E1E),
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.grey,
                elevation: 8,
                type: BottomNavigationBarType.fixed,
              ),
            ),
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

// Auth wrapper to check authentication status
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _checkAuthStatus();
    });
  }

  Future<void> _checkAuthStatus() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      final supabaseService = SupabaseService();
      final hasProfile = await supabaseService.hasCompletedProfile(
        session.user.id,
      );

      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _hasProfile = hasProfile;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _hasProfile = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: Skeleton.circle(size: 40)));
    }

    if (!_isAuthenticated) {
      return const LoginScreen();
    }

    if (!_hasProfile) {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final phone = Supabase.instance.client.auth.currentUser?.phone ?? '';
      return ProfileSetupScreen(userId: userId, phone: phone);
    }

    return const MainNavigationScaffold();
  }
}

class MainNavigationScaffold extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScaffold({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _pages = [
    const HomeFeedScreen(),
    const PlaceholderScreen(label: 'Search'),
    const PlaceholderScreen(label: 'Create'), // Placeholder for create
    const ReelsScreen(),
    const ProfileScreen(),
  ];

  static const _navIcons = [
    'assets/icons/Home.svg',
    'assets/icons/Search.svg',
    'assets/icons/Write.svg',
    'assets/icons/reel.svg',
    'assets/icons/Profile.svg',
  ];

  void _onNavTap(int index) async {
    // Special handling for create button (index 2)
    if (index == 2) {
      // Open ComposeScreen as a fullscreen dialog
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const ComposeScreen(),
          fullscreenDialog: true,
        ),
      );

      // If upload was successful (result == true), refresh the feed and go to home
      if (result == true && mounted) {
        setState(() => _selectedIndex = 0); // Switch to home tab
        // Refresh the content provider
        if (mounted) {
          await Provider.of<ContentProvider>(
            context,
            listen: false,
          ).refreshData();
        }
      }
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color:
                  isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: isDarkMode ? Colors.white : Colors.black,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          onTap: _onNavTap,
          items: List.generate(_navIcons.length, (index) {
            return BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(_selectedIndex == index ? 8 : 4),
                decoration: BoxDecoration(
                  color:
                      _selectedIndex == index
                          ? (isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05))
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _NavIcon(
                  assetPath: _navIcons[index],
                  isActive: _selectedIndex == index,
                ),
              ),
              label: '',
            );
          }),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.assetPath, required this.isActive});

  final String assetPath;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SvgPicture.asset(
      assetPath,
      width: 26,
      height: 26,
      colorFilter: ColorFilter.mode(
        isActive ? (isDarkMode ? Colors.white : Colors.black) : Colors.grey,
        BlendMode.srcIn,
      ),
    );
  }
}

class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, contentProvider, child) {
        if (contentProvider.isLoading) {
          return ListView.builder(
            itemCount: 3,
            itemBuilder: (context, index) => const PostSkeleton(),
          );
        }
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await Provider.of<ContentProvider>(
                context,
                listen: false,
              ).refreshData();
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      children: [
                        Image.asset('assets/images/kyuonlogo.png', width: 80),
                        const Spacer(),
                        FutureBuilder<int>(
                          future: MessagingService().getTotalUnreadCount(),
                          builder: (context, snapshot) {
                            final unreadCount = snapshot.data ?? 0;
                            return IconButton(
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(
                                    Icons.send,
                                    size: 24,
                                    color: Colors.black,
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          unreadCount > 99
                                              ? '99+'
                                              : '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => const MessagesScreen(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Text(
                          'Stories',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        SvgPicture.asset(
                          'assets/icons/Chevron.svg',
                          width: 16,
                          colorFilter: const ColorFilter.mode(
                            Colors.black,
                            BlendMode.srcIn,
                          ),
                        ),
                        const Spacer(),
                        SvgPicture.asset(
                          'assets/icons/Instagram.svg',
                          width: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 120,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: contentProvider.stories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        return StoryBubble(
                          data: contentProvider.stories[index],
                        );
                      },
                    ),
                  ),
                ),
                if (contentProvider.posts.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.feed,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No posts yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Posts count: ${contentProvider.posts.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Provider.of<ContentProvider>(
                                  context,
                                  listen: false,
                                ).refreshData();
                              },
                              child: const Text('Refresh'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= contentProvider.posts.length) {
                        return const SizedBox.shrink();
                      }
                      final post = contentProvider.posts[index];
                      return PostCard(data: post);
                    }, childCount: contentProvider.posts.length),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StoryBubble extends StatelessWidget {
  const StoryBubble({super.key, required this.data});

  final StoryData data;

  @override
  Widget build(BuildContext context) {
    // Check if user has an active story
    final hasStory = data.imageUrl != null && data.imageUrl!.isNotEmpty;

    final gradient =
        (data.isOwn && hasStory)
            ? const LinearGradient(
              colors: [Color(0xFF833AB4), Color(0xFFFF2E63), Color(0xFFFFC837)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
            : const LinearGradient(
              colors: [Color(0xFF333333), Color(0xFF000000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );

    return Column(
      children: [
        Stack(
          children: [
            // Story circle with tap detection
            GestureDetector(
              onTap: () {
                if (data.isOwn) {
                  if (hasStory) {
                    // View own story if it exists
                    _viewStory(context, data);
                  } else {
                    // Create new story if no story exists
                    _openCreateStory(context);
                  }
                } else {
                  // View other users' stories
                  _viewStory(context, data);
                }
              },
              child: Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      data.avatarUrl.isNotEmpty
                          ? data.avatarUrl
                          : 'https://i.pravatar.cc/150',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade300,
                          child: Icon(
                            Icons.person,
                            color: Colors.grey.shade600,
                            size: 36,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Plus button for own story (always visible for easy access)
            if (data.isOwn)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _openCreateStory(context),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 72,
          child: Text(
            data.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _openCreateStory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateStoryScreen()),
    );
  }

  void _viewStory(BuildContext context, StoryData storyData) {
    if (storyData.imageUrl == null || storyData.imageUrl!.isEmpty) {
      // No story to view
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${storyData.username} has no story'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Navigate to story viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewerScreen(story: storyData),
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.data});

  final PostData data;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  final Set<String> _likedPosts = {};
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize liked state from provider
    final provider = Provider.of<ContentProvider>(context, listen: false);
    _isLiked = provider.likedPosts.contains(widget.data.id);
    if (_isLiked) {
      _likedPosts.add(widget.data.id);
    }

    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_likedPosts.contains(widget.data.id)) {
      // Already liked, don't like again
      return;
    }

    setState(() {
      _isLiked = true;
      _likedPosts.add(widget.data.id);
    });

    _likeAnimationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _likeAnimationController.reverse();
        }
      });
    });

    Provider.of<ContentProvider>(
      context,
      listen: false,
    ).likePost(widget.data.id);
  }

  void _handleLikeButton() {
    final provider = Provider.of<ContentProvider>(context, listen: false);

    if (provider.likedPosts.contains(widget.data.id)) {
      // Already liked, so unlike it
      setState(() {
        _isLiked = false;
        _likedPosts.remove(widget.data.id);
      });
      provider.unlikePost(widget.data.id);
    } else {
      // Not liked yet, so like it
      setState(() {
        _isLiked = true;
        _likedPosts.add(widget.data.id);
      });
      provider.likePost(widget.data.id);
    }
  }

  void _handleComment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CommentsScreen(
              postId: widget.data.id,
              initialCommentCount: widget.data.replies,
            ),
      ),
    );
  }

  void _handleShare() async {
    final postUrl = 'https://kyuonapp.com/post/${widget.data.id}';
    final text =
        '${widget.data.username}: ${widget.data.body}\n\nCheck out this post on Kyuon!';

    try {
      await Share.share(text, subject: 'Check out this post!');
    } catch (e) {
      print('Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  void _navigateToProfile(String postId) async {
    try {
      // Get the post from database to find user_id
      final response =
          await Supabase.instance.client
              .from('posts')
              .select('user_id')
              .eq('id', postId)
              .single();

      final userId = response['user_id'];
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (userId == null) return;

      if (mounted) {
        if (currentUser != null && userId == currentUser.id) {
          // Navigate to MainNavigationScaffold with Profile tab selected
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder:
                  (context) => const MainNavigationScaffold(initialIndex: 4),
            ),
            (route) => false,
          );
        } else {
          // Navigate to other user's profile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtherUserProfileScreen(userId: userId),
            ),
          );
        }
      }
    } catch (e) {
      print('Error navigating to profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, provider, child) {
        // Find the latest version of this post from provider
        final updatedPost = provider.posts.firstWhere(
          (p) => p.id == widget.data.id,
          orElse: () => widget.data, // Fallback to original if not found
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _navigateToProfile(widget.data.id),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(
                        updatedPost.avatarUrl.isNotEmpty
                            ? updatedPost.avatarUrl
                            : 'https://i.pravatar.cc/150',
                      ),
                      onBackgroundImageError: (exception, stackTrace) {
                        // Handle error silently
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            updatedPost.username,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            updatedPost.timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SvgPicture.asset(
                      'assets/icons/More-circle.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                        Colors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                updatedPost.body,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              if (updatedPost.imageUrl != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onDoubleTap: _handleDoubleTap,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 4 / 5,
                          child: Image.network(
                            updatedPost.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, size: 50),
                              );
                            },
                          ),
                        ),
                      ),
                      // Like animation overlay
                      ScaleTransition(
                        scale: _likeAnimation,
                        child: Icon(
                          Icons.favorite,
                          color: Colors.white.withOpacity(0.9),
                          size: 100,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: _handleLikeButton,
                    child: _PostActionIcon(
                      assetPath: 'assets/icons/Like.svg',
                      isActive:
                          _isLiked || _likedPosts.contains(widget.data.id),
                    ),
                  ),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: _handleComment,
                    child: const _PostActionIcon(
                      assetPath: 'assets/icons/Comment.svg',
                    ),
                  ),
                  const SizedBox(width: 18),
                  const _PostActionIcon(assetPath: 'assets/icons/Repost.svg'),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: _handleShare,
                    child: const _PostActionIcon(
                      assetPath: 'assets/icons/Share.svg',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${updatedPost.likes} likes · ${updatedPost.replies} comments',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/GIF.svg',
                    width: 30,
                    colorFilter: const ColorFilter.mode(
                      Colors.grey,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SvgPicture.asset(
                    'assets/icons/Image.svg',
                    width: 30,
                    colorFilter: const ColorFilter.mode(
                      Colors.grey,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SvgPicture.asset(
                    'assets/icons/Poll.svg',
                    width: 30,
                    colorFilter: const ColorFilter.mode(
                      Colors.grey,
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _PostActionIcon extends StatelessWidget {
  const _PostActionIcon({required this.assetPath, this.isActive = false});

  final String assetPath;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(
        isActive ? Colors.red : Colors.black,
        BlendMode.srcIn,
      ),
    );
  }
}

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, contentProvider, child) {
        return RefreshIndicator(
          onRefresh: () => contentProvider.refreshData(),
          color: Colors.white,
          backgroundColor: Colors.black,
          child: CustomScrollView(
            slivers: [
              if (contentProvider.isLoading)
                const SliverFillRemaining(child: ReelSkeleton())
              else if (contentProvider.reels.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.video_library,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No reels yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Reels count: ${contentProvider.reels.length}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => contentProvider.refreshData(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ReelsPageView(reels: contentProvider.reels),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ReelsPageView extends StatefulWidget {
  const ReelsPageView({super.key, required this.reels});
  final List<ReelData> reels;

  @override
  State<ReelsPageView> createState() => _ReelsPageViewState();
}

class _ReelsPageViewState extends State<ReelsPageView>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final List<VideoPlayerController?> _controllers;
  int _selectedIndex = 0;
  final Map<int, bool> _initializedControllers = {};
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.reels.length, (index) => null);
    _initializeController(0); // Initialize first video immediately

    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  void _initializeController(int index) {
    if (index < 0 || index >= widget.reels.length) return;
    if (_controllers[index] != null) return; // Already initialized

    final reel = widget.reels[index];
    if (reel.videoUrl.isEmpty) {
      print('Warning: Reel at index $index has empty videoUrl');
      return;
    }

    print('Initializing video controller for index $index: ${reel.videoUrl}');

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(reel.videoUrl),
    );

    controller
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() {
              _controllers[index] = controller;
              _initializedControllers[index] = true;
            });
            controller.setLooping(true);
            if (index == _selectedIndex) {
              controller.play();
              print('Playing video at index $index');
            }
          }
        })
        .catchError((error) {
          print('Error initializing video at index $index: $error');
          if (mounted) {
            setState(() {
              _controllers[index] = null;
            });
          }
        });
  }

  void _playController(int index) {
    for (int i = 0; i < _controllers.length; i++) {
      final controller = _controllers[i];
      if (controller != null && controller.value.isInitialized) {
        if (i == index) {
          controller.play();
        } else {
          controller.pause();
        }
      }
    }

    // Initialize adjacent videos for smooth scrolling
    if (index > 0) _initializeController(index - 1);
    if (index < widget.reels.length - 1) _initializeController(index + 1);
  }

  String _formatLikes(double likes) {
    if (likes >= 1000000) {
      return '${(likes / 1000000).toStringAsFixed(1)}M';
    } else if (likes >= 1000) {
      return '${(likes / 1000).toStringAsFixed(1)}K';
    } else {
      return likes.toStringAsFixed(0);
    }
  }

  void _handleDoubleTap(ReelData reel) {
    final provider = Provider.of<ContentProvider>(context, listen: false);

    if (provider.likedReels.contains(reel.id)) {
      // Already liked, don't like again
      return;
    }

    // Show heart animation
    _likeAnimationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _likeAnimationController.reverse();
        }
      });
    });

    provider.likeReel(reel.id);
  }

  void _handleLikeButton(ReelData reel) {
    final provider = Provider.of<ContentProvider>(context, listen: false);

    if (provider.likedReels.contains(reel.id)) {
      // Already liked, so unlike it
      provider.unlikeReel(reel.id);
    } else {
      // Not liked yet, so like it
      // Show heart animation just like double tap
      _likeAnimationController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _likeAnimationController.reverse();
          }
        });
      });

      provider.likeReel(reel.id);
    }
  }

  void _handleComment(ReelData reel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => CommentsScreen(
              postId: reel.id,
              initialCommentCount: reel.comments,
              contentType: 'reel', // Specify this is a reel comment
            ),
        fullscreenDialog: true,
      ),
    );
  }

  void _handleShare(ReelData reel) async {
    final reelUrl = 'https://kyuonapp.com/reel/${reel.id}';
    final text =
        '${reel.username}: ${reel.caption}\n\nCheck out this reel on Kyuon!\n$reelUrl';

    try {
      await Share.share(text, subject: 'Check out this reel!');
    } catch (e) {
      print('Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  void _navigateToProfile(String reelId) async {
    try {
      // Get the reel from database to find uploader_id
      final response =
          await Supabase.instance.client
              .from('videos')
              .select('uploader_id')
              .eq('id', reelId)
              .single();

      final userId = response['uploader_id'];
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (userId == null) return;

      if (mounted) {
        if (currentUser != null && userId == currentUser.id) {
          // Navigate to MainNavigationScaffold with Profile tab selected
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder:
                  (context) => const MainNavigationScaffold(initialIndex: 4),
            ),
            (route) => false,
          );
        } else {
          // Navigate to other user's profile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtherUserProfileScreen(userId: userId),
            ),
          );
        }
      }
    } catch (e) {
      print('Error navigating to profile: $e');
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller?.dispose();
    }
    _pageController.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.reels.length,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
          _playController(index);
        },
        itemBuilder: (context, index) {
          final controller = _controllers[index];
          final provider = Provider.of<ContentProvider>(context);
          // Get reel from provider to ensure we have latest data
          final reel = provider.reels[index];
          final isLiked = provider.likedReels.contains(reel.id);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Video Player
              if (controller != null && controller.value.isInitialized)
                GestureDetector(
                  onTap: () {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  },
                  onDoubleTap: () => _handleDoubleTap(reel),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      ),
                      // Like animation overlay
                      ScaleTransition(
                        scale: _likeAnimation,
                        child: Icon(
                          Icons.favorite,
                          color: Colors.white.withOpacity(0.9),
                          size: 100,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                const ReelSkeleton(),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              Positioned(
                top: 48,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/kyuonlogo_splash.png',
                      width: 72,
                    ),
                    const Spacer(),
                    SvgPicture.asset(
                      'assets/icons/More.svg',
                      width: 24,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 40,
                left: 20,
                right: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToProfile(reel.id),
                      child: Text(
                        '@${reel.username}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reel.caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 60,
                right: 16,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _handleLikeButton(reel),
                      child: _ReelActionIcon(
                        assetPath: 'assets/icons/Like.svg',
                        label: _formatLikes(reel.likes),
                        isActive: isLiked,
                      ),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () => _handleComment(reel),
                      child: _ReelActionIcon(
                        assetPath: 'assets/icons/Comment.svg',
                        label: '${reel.comments}',
                      ),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () => _handleShare(reel),
                      child: _ReelActionIcon(
                        assetPath: 'assets/icons/Share.svg',
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ReelActionIcon(assetPath: 'assets/icons/More-circle.svg'),
                  ],
                ),
              ),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.reels.length, (dotIndex) {
                    final isActive = dotIndex == _selectedIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 24 : 8,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReelActionIcon extends StatelessWidget {
  const _ReelActionIcon({
    required this.assetPath,
    this.label,
    this.isActive = false,
  });

  final String assetPath;
  final String? label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SvgPicture.asset(
          assetPath,
          width: 28,
          colorFilter: ColorFilter.mode(
            isActive ? Colors.red : Colors.white,
            BlendMode.srcIn,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$label coming soon',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }
}
