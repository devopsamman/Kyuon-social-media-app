class StoryData {
  StoryData({
    required this.username,
    required this.avatarUrl,
    this.imageUrl,
    this.isOwn = false,
  });

  final String username;
  final String avatarUrl;
  final String? imageUrl;
  final bool isOwn;

  factory StoryData.fromJson(Map<String, dynamic> json, {bool isOwn = false}) {
    // Stories table has user_name and user_avatar directly
    return StoryData(
      username: json['user_name'] ?? 'Unknown',
      avatarUrl: json['user_avatar'] ?? 'https://i.pravatar.cc/150',
      imageUrl: json['image_url'],
      isOwn: isOwn,
    );
  }
}
