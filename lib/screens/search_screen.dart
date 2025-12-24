import 'package:flutter/material.dart';
import '../services/search_service.dart';
import '../models/post_data.dart';
import '../models/reel_data.dart';
import 'other_user_profile_screen.dart';
import 'profile_screen.dart';
import 'user_posts_view.dart';
import 'user_reels_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // For MainNavigationScaffold
import 'dart:async';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  SearchResult? _searchResults;
  List<String> _searchHistory = [];
  bool _isSearching = false;
  Timer? _debounce;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        // _selectedTab = _tabController.index; // This line is no longer needed
      });
    });
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await _searchService.getSearchHistory();
    if (mounted) {
      setState(() {
        _searchHistory = history;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = null;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    final results = await _searchService.searchAll(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    await _searchService.clearSearchHistory();
    setState(() {
      _searchHistory = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        title: _buildSearchBar(isDarkMode),
        bottom:
            _searchResults != null
                ? TabBar(
                  controller: _tabController,
                  labelColor: isDarkMode ? Colors.white : Colors.black,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).primaryColor,
                  tabs: [
                    Tab(text: 'All'),
                    Tab(text: 'Users'),
                    Tab(text: 'Posts'),
                    Tab(text: 'Reels'),
                  ],
                )
                : null,
      ),
      body: _buildBody(isDarkMode),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        onSubmitted: (query) async {
          // Save to search history only when user presses Enter/Submit
          if (query.trim().isNotEmpty) {
            await _searchService.saveSearchHistory(query);
            await _loadSearchHistory(); // Reload history to show new entry
          }
          // Close keyboard after submit
          _searchFocusNode.unfocus();
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search users, posts, reels...',
          hintStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade600),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = null;
                      });
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults == null) {
      return _buildSearchHistory(isDarkMode);
    }

    if (_searchResults!.isEmpty) {
      return _buildEmptyState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildAllResults(isDarkMode),
        _buildUserResults(isDarkMode),
        _buildPostResults(isDarkMode),
        _buildReelResults(isDarkMode),
      ],
    );
  }

  Widget _buildSearchHistory(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_searchHistory.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                TextButton(
                  onPressed: _clearHistory,
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchHistory.length,
              itemBuilder: (context, index) {
                final query = _searchHistory[index];
                return ListTile(
                  leading: Icon(
                    Icons.history,
                    color:
                        isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                  ),
                  title: Text(
                    query,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    onPressed: () async {
                      // Remove single item from history
                      setState(() {
                        _searchHistory.removeAt(index);
                      });
                    },
                  ),
                  onTap: () {
                    // Click on history item to search again
                    _searchController.text = query;
                    _performSearch(query);
                  },
                );
              },
            ),
          ),
        ] else
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Search for users, posts, or reels',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try searching for usernames or content',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildAllResults(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_searchResults!.users.isNotEmpty) ...[
            _buildSectionHeader('Users', isDarkMode),
            ...(_searchResults!.users
                .take(3)
                .map((user) => _buildUserTile(user, isDarkMode))),
          ],
          if (_searchResults!.posts.isNotEmpty) ...[
            _buildSectionHeader('Posts', isDarkMode),
            _buildPostsGrid(_searchResults!.posts.take(6).toList()),
          ],
          if (_searchResults!.reels.isNotEmpty) ...[
            _buildSectionHeader('Reels', isDarkMode),
            _buildReelsGrid(_searchResults!.reels.take(6).toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildUserResults(bool isDarkMode) {
    if (_searchResults!.users.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return ListView.builder(
      itemCount: _searchResults!.users.length,
      itemBuilder: (context, index) {
        return _buildUserTile(_searchResults!.users[index], isDarkMode);
      },
    );
  }

  Widget _buildPostResults(bool isDarkMode) {
    if (_searchResults!.posts.isEmpty) {
      return const Center(child: Text('No posts found'));
    }

    return _buildPostsGrid(_searchResults!.posts);
  }

  Widget _buildReelResults(bool isDarkMode) {
    if (_searchResults!.reels.isEmpty) {
      return const Center(child: Text('No reels found'));
    }

    return _buildReelsGrid(_searchResults!.reels);
  }

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildUserTile(UserSearchResult user, bool isDarkMode) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isCurrentUser = currentUserId == user.id;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            user.profileImageUrl != null
                ? NetworkImage(user.profileImageUrl!)
                : null,
        backgroundColor: Colors.grey.shade300,
        child:
            user.profileImageUrl == null
                ? Icon(Icons.person, color: Colors.grey.shade600)
                : null,
      ),
      title: Text(
        user.username,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: user.fullName != null ? Text(user.fullName!) : null,
      trailing: Text(
        '${user.followersCount} followers',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      onTap: () {
        if (isCurrentUser) {
          // Navigate to profile tab (replaces current route to show bottom nav)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) => const MainNavigationScaffold(initialIndex: 4),
            ),
          );
        } else {
          // Navigate to other user's profile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtherUserProfileScreen(userId: user.id),
            ),
          );
        }
      },
    );
  }

  Widget _buildPostsGrid(List<PostSearchResult> posts) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () {
            // Convert search results to PostData for UserPostsView
            final postDataList =
                posts
                    .map(
                      (p) => PostData(
                        id: p.id,
                        username: p.username,
                        avatarUrl: p.profileImageUrl ?? '',
                        timeAgo: _formatTimeAgo(p.createdAt),
                        body: p.content ?? '',
                        imageUrl: p.imageUrl,
                        likes: 0,
                        replies: 0,
                      ),
                    )
                    .toList();

            // Open UserPostsView starting from clicked post
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        UserPostsView(posts: postDataList, initialIndex: index),
              ),
            );
          },
          child: Image.network(post.imageUrl, fit: BoxFit.cover),
        );
      },
    );
  }

  Widget _buildReelsGrid(List<ReelSearchResult> reels) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: reels.length,
      itemBuilder: (context, index) {
        final reel = reels[index];
        return GestureDetector(
          onTap: () {
            // Convert search results to ReelData for UserReelsView
            final reelDataList =
                reels
                    .map(
                      (r) => ReelData(
                        id: r.id,
                        username: r.username,
                        avatarUrl: r.profileImageUrl ?? '',
                        videoUrl: r.videoUrl,
                        thumbnailUrl: r.thumbnailUrl ?? '',
                        caption: r.title ?? '',
                        likes: 0,
                        comments: 0,
                      ),
                    )
                    .toList();

            // Open UserReelsView starting from clicked reel
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        UserReelsView(reels: reelDataList, initialIndex: index),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              reel.thumbnailUrl != null
                  ? Image.network(reel.thumbnailUrl!, fit: BoxFit.cover)
                  : Container(color: Colors.grey.shade800),
              const Positioned(
                bottom: 8,
                left: 8,
                child: Icon(Icons.play_arrow, color: Colors.white, size: 24),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
