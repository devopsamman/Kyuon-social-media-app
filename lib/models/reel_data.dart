class ReelData {
  ReelData({
    required this.id,
    required this.username,
    required this.caption,
    required this.videoUrl,
    this.thumbnailUrl = '',
    this.avatarUrl = '',
    this.likes = 0,
    this.comments = 0,
  });

  final String id;
  final String username;
  final String caption;
  final String videoUrl;
  final String thumbnailUrl;
  final String avatarUrl;
  final double likes;
  final int comments;

  factory ReelData.fromJson(Map<String, dynamic> json) {
    try {
      final profile = json['profiles'] ?? {};
      // Use title or description if available, otherwise empty string
      final caption = json['title'] ?? json['description'] ?? '';
      final videoUrl = json['video_url']?.toString() ?? '';
      final thumbnailUrl = json['thumbnail_url']?.toString() ?? '';

      // Validate video URL
      if (videoUrl.isEmpty) {
        print('Warning: Reel has empty video_url');
      } else if (!videoUrl.contains('cloudinary.com') &&
          !videoUrl.startsWith('http')) {
        print('Warning: Reel video_url may be invalid: $videoUrl');
      }

      return ReelData(
        id: json['id']?.toString() ?? '',
        username: profile['username']?.toString() ?? 'Unknown',
        caption: caption.toString(),
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        avatarUrl: profile['profile_image_url']?.toString() ?? '',
        likes: (json['likes'] ?? 0).toDouble(),
        comments: (json['comments'] ?? 0) as int,
      );
    } catch (e, stackTrace) {
      print('Error parsing ReelData: $e');
      print('Stack trace: $stackTrace');
      print('JSON: $json');
      rethrow;
    }
  }
}
