import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/story_data.dart';

class StoryViewerScreen extends StatefulWidget {
  final StoryData story;

  const StoryViewerScreen({super.key, required this.story});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _timer;
  static const Duration _storyDuration = Duration(seconds: 15);

  int _currentStoryIndex = 0;
  late List<StoryData> _stories;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    // Hide status bar for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Get all stories for this user
    _stories =
        widget.story.allStories.isNotEmpty
            ? widget.story.allStories
            : [widget.story];

    // Initialize progress animation
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    );

    // Start first story
    _startStory();
  }

  void _startStory() {
    _progressController.reset();
    _progressController.forward();

    _timer?.cancel();
    _timer = Timer(_storyDuration, () {
      _nextStory();
    });
  }

  void _nextStory() {
    if (_currentStoryIndex < _stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _startStory();
    } else {
      // All stories viewed, close viewer
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startStory();
    } else {
      // At first story, close viewer
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _progressController.stop();
      _timer?.cancel();
    } else {
      final remaining = _storyDuration * (1 - _progressController.value);
      _progressController.forward();
      _timer = Timer(remaining, () {
        _nextStory();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    // Restore status bar
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;

    if (tapPosition < screenWidth / 3) {
      // Left tap - Previous story
      _previousStory();
    } else if (tapPosition > 2 * screenWidth / 3) {
      // Right tap - Next story
      _nextStory();
    } else {
      // Middle tap - Pause/Resume
      _togglePause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStory = _stories[_currentStoryIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _handleTap,
        child: Stack(
          children: [
            // Story Image
            Center(
              child:
                  currentStory.imageUrl != null
                      ? Image.network(
                        currentStory.imageUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 64,
                            ),
                          );
                        },
                      )
                      : const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
            ),

            // Progress bars at top (one per story)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: List.generate(_stories.length, (index) {
                      return Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, child) {
                              double progress;
                              if (index < _currentStoryIndex) {
                                progress = 1.0; // Completed
                              } else if (index == _currentStoryIndex) {
                                progress = _progressController.value; // Current
                              } else {
                                progress = 0.0; // Not started
                              }

                              return LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                minHeight: 2,
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),

            // User info at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(widget.story.avatarUrl),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.story.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 8),
                              ],
                            ),
                          ),
                          if (_stories.length > 1)
                            Text(
                              '${_currentStoryIndex + 1}/${_stories.length}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 8),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      if (_isPaused)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(
                            Icons.pause_circle_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
