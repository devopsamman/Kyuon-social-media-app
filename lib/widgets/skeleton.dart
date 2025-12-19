import 'package:flutter/material.dart';

/// Shimmer skeleton loading widget
class Skeleton extends StatefulWidget {
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;

  const Skeleton({super.key, this.height, this.width, this.borderRadius});

  const Skeleton.circle({super.key, required double size})
    : height = size,
      width = size,
      borderRadius = null;

  const Skeleton.rectangle({super.key, required this.height, this.width})
    : borderRadius = null;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(_animation.value, 0),
              end: const Alignment(1, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Post skeleton loader
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Skeleton.circle(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton.rectangle(height: 12, width: 120),
                    const SizedBox(height: 6),
                    Skeleton.rectangle(height: 10, width: 80),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Caption
          Skeleton.rectangle(height: 14, width: double.infinity),
          const SizedBox(height: 6),
          Skeleton.rectangle(height: 14, width: 250),
          const SizedBox(height: 12),
          // Image
          Container(
            height: 400,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
            child: const Skeleton(
              height: 400,
              width: double.infinity,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Skeleton.rectangle(height: 24, width: 24),
              const SizedBox(width: 18),
              Skeleton.rectangle(height: 24, width: 24),
              const SizedBox(width: 18),
              Skeleton.rectangle(height: 24, width: 24),
              const SizedBox(width: 18),
              Skeleton.rectangle(height: 24, width: 24),
            ],
          ),
          const SizedBox(height: 10),
          Skeleton.rectangle(height: 12, width: 180),
          const Divider(height: 32),
        ],
      ),
    );
  }
}

/// Reel skeleton loader
class ReelSkeleton extends StatelessWidget {
  const ReelSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Stack(
        fit: StackFit.expand,
        children: [
          // Full screen skeleton
          Skeleton(height: double.infinity, width: double.infinity),
          // Bottom text area
          Positioned(
            bottom: 60,
            left: 20,
            right: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Skeleton.rectangle(height: 16, width: 150),
                SizedBox(height: 8),
                Skeleton.rectangle(height: 14, width: 250),
              ],
            ),
          ),
          // Right action buttons
          Positioned(
            bottom: 60,
            right: 16,
            child: Column(
              children: [
                Skeleton.circle(size: 48),
                SizedBox(height: 18),
                Skeleton.circle(size: 48),
                SizedBox(height: 18),
                Skeleton.circle(size: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile skeleton loader
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile header
            Row(
              children: [
                const Skeleton.circle(size: 80),
                const SizedBox(width: 20),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Skeleton.rectangle(height: 16, width: 40),
                          const SizedBox(height: 4),
                          Skeleton.rectangle(height: 12, width: 50),
                        ],
                      ),
                      Column(
                        children: [
                          Skeleton.rectangle(height: 16, width: 40),
                          const SizedBox(height: 4),
                          Skeleton.rectangle(height: 12, width: 60),
                        ],
                      ),
                      Column(
                        children: [
                          Skeleton.rectangle(height: 16, width: 40),
                          const SizedBox(height: 4),
                          Skeleton.rectangle(height: 12, width: 70),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Name and bio
            Skeleton.rectangle(height: 14, width: double.infinity),
            const SizedBox(height: 8),
            Skeleton.rectangle(height: 12, width: 250),
            const SizedBox(height: 16),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: Skeleton.rectangle(height: 32, width: double.infinity),
                ),
                const SizedBox(width: 8),
                Skeleton.rectangle(height: 32, width: 32),
              ],
            ),
            const SizedBox(height: 24),
            // Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                return const Skeleton(
                  height: double.infinity,
                  width: double.infinity,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Story bubble skeleton
class StorySkeleton extends StatelessWidget {
  const StorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Skeleton.circle(size: 64),
          SizedBox(height: 4),
          Skeleton.rectangle(height: 10, width: 60),
        ],
      ),
    );
  }
}

/// Comment skeleton
class CommentSkeleton extends StatelessWidget {
  const CommentSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton.circle(size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton.rectangle(height: 12, width: 100),
                const SizedBox(height: 6),
                Skeleton.rectangle(height: 10, width: double.infinity),
                const SizedBox(height: 4),
                Skeleton.rectangle(height: 10, width: 200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
