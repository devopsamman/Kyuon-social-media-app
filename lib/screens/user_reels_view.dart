import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../models/reel_data.dart';
import '../services/content_provider.dart';
import '../screens/comments_screen.dart';
import '../widgets/skeleton.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'other_user_profile_screen.dart';

// Displays user's reels in vertical video player starting from initial index
class UserReelsView extends StatefulWidget {
  final List<ReelData> reels;
  final int initialIndex;

  const UserReelsView({
    super.key,
    required this.reels,
    required this.initialIndex,
  });

  @override
  State<UserReelsView> createState() => _UserReelsViewState();
}

// Exact implementation from main.dart _ReelsPageViewState
class _UserReelsViewState extends State<UserReelsView>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late final List<VideoPlayerController?> _controllers;
  int _currentIndex = 0;
  final Map<int, bool> _initializedControllers = {};
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _controllers = List.generate(widget.reels.length, (index) => null);
    _initializeController(widget.initialIndex); // Initialize first video

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
            if (index == _currentIndex) {
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
          setState(() => _currentIndex = index);
          _playController(index);
        },
        itemBuilder: (context, index) {
          final controller = _controllers[index];
          final provider = Provider.of<ContentProvider>(context);

          // Get the original reel ID to look up current data
          final originalReel = widget.reels[index];

          // Find the latest version of this reel from provider
          final reel = provider.reels.firstWhere(
            (r) => r.id == originalReel.id,
            orElse: () => originalReel, // Fallback to original if not found
          );

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
              // Back button
              Positioned(
                top: 48,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // More button
              Positioned(
                top: 48,
                right: 20,
                child: SvgPicture.asset(
                  'assets/icons/More.svg',
                  width: 24,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
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
                    final isActive = dotIndex == _currentIndex;
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
