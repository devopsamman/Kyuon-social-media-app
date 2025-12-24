import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post_data.dart';
import '../services/content_provider.dart';
import '../screens/comments_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'other_user_profile_screen.dart';

// Displays user's posts in vertical feed starting from initial index
class UserPostsView extends StatefulWidget {
  final List<PostData> posts;
  final int initialIndex;

  const UserPostsView({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  @override
  State<UserPostsView> createState() => _UserPostsViewState();
}

class _UserPostsViewState extends State<UserPostsView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Posts', style: TextStyle(color: Colors.black)),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        itemBuilder: (context, index) {
          return SingleChildScrollView(
            child: PostCard(data: widget.posts[index]),
          );
        },
      ),
    );
  }
}

// Exact PostCard from main.dart
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
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Navigate to profile tab
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  const MainNavigationScaffold(initialIndex: 4),
                        ),
                        (route) => false,
                      );
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(
                        updatedPost.avatarUrl.isNotEmpty
                            ? updatedPost.avatarUrl
                            : 'https://i.pravatar.cc/150',
                      ),
                      onBackgroundImageError: (exception, stackTrace) {
                        // Handle error silently
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Navigate to profile tab
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const MainNavigationScaffold(
                                  initialIndex: 4,
                                ),
                          ),
                          (route) => false,
                        );
                      },
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
