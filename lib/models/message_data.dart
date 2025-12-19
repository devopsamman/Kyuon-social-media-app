class ConversationData {
  final String id;
  final String user1Id;
  final String user2Id;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final int user1UnreadCount;
  final int user2UnreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed fields (from joined profile data)
  final String otherUserName;
  final String otherUserAvatar;
  final String otherUserId;

  ConversationData({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    required this.user1UnreadCount,
    required this.user2UnreadCount,
    required this.createdAt,
    required this.updatedAt,
    required this.otherUserName,
    required this.otherUserAvatar,
    required this.otherUserId,
  });

  factory ConversationData.fromJson(
    Map<String, dynamic> json,
    String currentUserId,
  ) {
    // Determine who the "other user" is
    final isUser1 = currentUserId == json['user1_id'];
    final otherUserId = isUser1 ? json['user2_id'] : json['user1_id'];

    // Get other user's profile data
    final otherUserProfile =
        json['other_user_profile'] as Map<String, dynamic>?;

    return ConversationData(
      id: json['id'] as String,
      user1Id: json['user1_id'] as String,
      user2Id: json['user2_id'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageAt:
          json['last_message_at'] != null
              ? DateTime.parse(json['last_message_at'] as String)
              : null,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      user1UnreadCount: json['user1_unread_count'] as int? ?? 0,
      user2UnreadCount: json['user2_unread_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      otherUserName: otherUserProfile?['username'] as String? ?? 'User',
      otherUserAvatar: otherUserProfile?['profile_image_url'] as String? ?? '',
      otherUserId: otherUserId as String,
    );
  }

  int getUnreadCount(String currentUserId) {
    return currentUserId == user1Id ? user1UnreadCount : user2UnreadCount;
  }
}

class MessageData {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String messageText;
  final String messageType;
  final String? mediaUrl;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed fields
  final String senderName;
  final String senderAvatar;

  MessageData({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.messageText,
    required this.messageType,
    this.mediaUrl,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
    required this.senderName,
    required this.senderAvatar,
  });

  factory MessageData.fromJson(Map<String, dynamic> json) {
    final senderProfile = json['sender_profile'] as Map<String, dynamic>?;

    return MessageData(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      messageText: json['message_text'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      readAt:
          json['read_at'] != null
              ? DateTime.parse(json['read_at'] as String)
              : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      senderName: senderProfile?['username'] as String? ?? 'User',
      senderAvatar: senderProfile?['profile_image_url'] as String? ?? '',
    );
  }

  bool isSentByMe(String currentUserId) {
    return senderId == currentUserId;
  }
}
