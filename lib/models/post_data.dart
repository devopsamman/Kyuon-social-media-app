class PostData {
  PostData({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.timeAgo,
    required this.body,
    this.imageUrl,
    this.likes = 0,
    this.replies = 0,
  });

  final String id;
  final String username;
  final String avatarUrl;
  final String timeAgo;
  final String body;
  final String? imageUrl;
  final int likes;
  final int replies;

  factory PostData.fromJson(Map<String, dynamic> json) {
    try {
      // Handle profiles - Supabase PostgREST returns joined data as nested object
      Map<String, dynamic> profile = {};
      final profilesData = json['profiles'];
      
      if (profilesData != null) {
        if (profilesData is List) {
          // If it's a list, take the first item
          if (profilesData.isNotEmpty && profilesData.first is Map) {
            profile = Map<String, dynamic>.from(profilesData.first as Map);
          }
        } else if (profilesData is Map) {
          // If it's already a map, use it directly
          profile = Map<String, dynamic>.from(profilesData);
        }
      }
      
      // Ensure we have valid data
      final id = json['id']?.toString();
      if (id == null || id.isEmpty) {
        print('Warning: Post ID is missing or empty');
        throw Exception('Post ID is missing');
      }
      
      final username = profile['username']?.toString() ?? 'Unknown';
      final avatarUrl = profile['profile_image_url']?.toString() ?? 'https://i.pravatar.cc/150';
      final body = json['content']?.toString() ?? '';
      
    return PostData(
        id: id,
        username: username,
        avatarUrl: avatarUrl,
        timeAgo: _calculateTimeAgo(json['created_at']?.toString()),
        body: body,
        imageUrl: json['image_url']?.toString(),
        likes: (json['likes'] is int) ? json['likes'] as int : (json['likes'] is num) ? (json['likes'] as num).toInt() : 0,
        replies: (json['comments'] is int) ? json['comments'] as int : (json['comments'] is num) ? (json['comments'] as num).toInt() : 0,
    );
    } catch (e, stackTrace) {
      print('Error in PostData.fromJson: $e');
      print('Stack trace: $stackTrace');
      print('JSON keys: ${json.keys}');
      print('JSON data: $json');
      rethrow;
    }
  }

  static String _calculateTimeAgo(String? createdAt) {
    if (createdAt == null) return 'now';
    final date = DateTime.parse(createdAt);
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'now';
  }
}
