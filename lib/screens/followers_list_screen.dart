import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'other_user_profile_screen.dart';

class FollowersListScreen extends StatefulWidget {
  final String userId; // The user whose followers/following we're viewing
  final bool isFollowersList; // true for followers, false for following
  final bool isOwnProfile; // true if viewing own profile

  const FollowersListScreen({
    super.key,
    required this.userId,
    required this.isFollowersList,
    required this.isOwnProfile,
  });

  @override
  State<FollowersListScreen> createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends State<FollowersListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  final _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      setState(() => _isLoading = true);

      if (widget.isFollowersList) {
        // Fetch followers - users who follow this profile
        final followersData = await Supabase.instance.client
            .from('followers')
            .select('follower_id')
            .eq('following_id', widget.userId);

        if (followersData.isNotEmpty) {
          final followerIds =
              (followersData as List)
                  .map((e) => e['follower_id'] as String)
                  .toList();

          // Fetch profile data for all followers
          final profilesData = await Supabase.instance.client
              .from('profiles')
              .select()
              .inFilter('id', followerIds);

          // Check if current user is following each of these users
          if (_currentUserId != null) {
            final currentUserFollowing = await Supabase.instance.client
                .from('followers')
                .select('following_id')
                .eq('follower_id', _currentUserId);

            final followingIds =
                (currentUserFollowing as List)
                    .map((e) => e['following_id'] as String)
                    .toSet();

            _users =
                (profilesData as List).map((profile) {
                  return {
                    ...Map<String, dynamic>.from(profile),
                    'is_following': followingIds.contains(profile['id']),
                  };
                }).toList();
          } else {
            _users =
                (profilesData as List)
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
          }
        }
      } else {
        // Fetch following - users this profile is following
        final followingData = await Supabase.instance.client
            .from('followers')
            .select('following_id')
            .eq('follower_id', widget.userId);

        if (followingData.isNotEmpty) {
          final followingIds =
              (followingData as List)
                  .map((e) => e['following_id'] as String)
                  .toList();

          // Fetch profile data for all following
          final profilesData = await Supabase.instance.client
              .from('profiles')
              .select()
              .inFilter('id', followingIds);

          _users =
              (profilesData as List)
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFollower(String followerId) async {
    try {
      // Remove the follower relationship
      await Supabase.instance.client
          .from('followers')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', widget.userId);

      // Refresh the list
      _fetchUsers();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Follower removed')));
      }
    } catch (e) {
      print('Error removing follower: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _followBack(String userId, int index) async {
    try {
      if (_currentUserId == null) return;

      // Add follow relationship
      await Supabase.instance.client.from('followers').insert({
        'follower_id': _currentUserId,
        'following_id': userId,
      });

      // Update local state
      setState(() {
        _users[index]['is_following'] = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Following')));
      }
    } catch (e) {
      print('Error following user: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _unfollow(String userId) async {
    try {
      if (_currentUserId == null) return;

      // Remove follow relationship
      await Supabase.instance.client
          .from('followers')
          .delete()
          .eq('follower_id', _currentUserId)
          .eq('following_id', userId);

      // Refresh the list
      _fetchUsers();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unfollowed')));
      }
    } catch (e) {
      print('Error unfollowing user: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openUserProfile(String userId) {
    if (userId == _currentUserId) {
      // Don't navigate to own profile, already there
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        title: Text(
          widget.isFollowersList ? 'Followers' : 'Following',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
              ? Center(
                child: Text(
                  widget.isFollowersList
                      ? 'No followers yet'
                      : 'Not following anyone yet',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey : Colors.grey.shade700,
                  ),
                ),
              )
              : ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final isFollowing = user['is_following'] ?? false;

                  return ListTile(
                    onTap: () => _openUserProfile(user['id']),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage:
                          user['profile_image_url'] != null &&
                                  user['profile_image_url']
                                      .toString()
                                      .isNotEmpty
                              ? NetworkImage(user['profile_image_url'])
                              : null,
                      backgroundColor:
                          isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                      child:
                          user['profile_image_url'] == null ||
                                  user['profile_image_url'].toString().isEmpty
                              ? Icon(
                                Icons.person,
                                color:
                                    isDarkMode
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                              )
                              : null,
                    ),
                    title: Text(
                      user['username'] ?? 'Unknown',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle:
                        user['full_name'] != null &&
                                user['full_name'].toString().isNotEmpty
                            ? Text(
                              user['full_name'],
                              style: TextStyle(
                                color:
                                    isDarkMode
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                              ),
                            )
                            : null,
                    trailing:
                        widget.isOwnProfile
                            ? _buildActionButton(
                              user['id'],
                              index,
                              isFollowing,
                              isDarkMode,
                            )
                            : null,
                  );
                },
              ),
    );
  }

  Widget? _buildActionButton(
    String userId,
    int index,
    bool isFollowing,
    bool isDarkMode,
  ) {
    if (widget.isFollowersList) {
      // For followers list: show "Remove" and "Follow Back" buttons
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFollowing)
            TextButton(
              onPressed: () => _followBack(userId, index),
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Follow Back'),
            ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _removeFollower(userId),
            style: TextButton.styleFrom(
              backgroundColor:
                  isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              foregroundColor: isDarkMode ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      );
    } else {
      // For following list: show "Unfollow" button
      return TextButton(
        onPressed: () => _unfollow(userId),
        style: TextButton.styleFrom(
          backgroundColor:
              isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
          foregroundColor: isDarkMode ? Colors.white : Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Unfollow'),
      );
    }
  }
}
