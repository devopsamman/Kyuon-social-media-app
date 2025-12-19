import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_data.dart';

class MessagingService {
  final _supabase = Supabase.instance.client;

  // Get all conversations for current user
  Future<List<ConversationData>> getConversations() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return [];

      print('📥 Fetching conversations for user: $currentUserId');

      final response = await _supabase
          .from('conversations')
          .select()
          .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId')
          .order('updated_at', ascending: false);

      print('✅ Fetched ${(response as List).length} conversations');

      // Fetch other users' profiles
      final conversations = <ConversationData>[];
      for (var conv in response) {
        final otherUserId =
            conv['user1_id'] == currentUserId
                ? conv['user2_id']
                : conv['user1_id'];

        final profileResponse =
            await _supabase
                .from('profiles')
                .select()
                .eq('id', otherUserId)
                .single();

        conv['other_user_profile'] = profileResponse;
        conversations.add(ConversationData.fromJson(conv, currentUserId));
      }

      return conversations;
    } catch (e) {
      print('❌ Error fetching conversations: $e');
      return [];
    }
  }

  // Get messages for a conversation
  Future<List<MessageData>> getMessages(String conversationId) async {
    try {
      print('📥 Fetching messages for conversation: $conversationId');

      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      print('✅ Fetched ${(response as List).length} messages');

      // Fetch sender profiles
      final messages = <MessageData>[];
      for (var msg in response) {
        final senderProfile =
            await _supabase
                .from('profiles')
                .select()
                .eq('id', msg['sender_id'])
                .single();

        msg['sender_profile'] = senderProfile;
        messages.add(MessageData.fromJson(msg));
      }

      return messages;
    } catch (e) {
      print('❌ Error fetching messages: $e');
      return [];
    }
  }

  // Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String receiverId,
    required String messageText,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Not authenticated');

      print('📤 Sending message to conversation: $conversationId');

      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'receiver_id': receiverId,
        'message_text': messageText,
        'message_type': messageType,
        'media_url': mediaUrl,
      });

      print('✅ Message sent successfully');
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  // Get or create conversation between two users
  Future<String> getOrCreateConversation(String otherUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Not authenticated');

      print('🔄 Getting or creating conversation with: $otherUserId');

      final response = await _supabase.rpc(
        'get_or_create_conversation',
        params: {'p_user1_id': currentUserId, 'p_user2_id': otherUserId},
      );

      print('✅ Conversation ID: $response');
      return response as String;
    } catch (e) {
      print('❌ Error getting/creating conversation: $e');
      rethrow;
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      print('✔️ Marking messages as read for conversation: $conversationId');

      await _supabase.rpc(
        'mark_messages_as_read',
        params: {
          'p_conversation_id': conversationId,
          'p_user_id': currentUserId,
        },
      );

      print('✅ Messages marked as read');
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

  // Get total unread count
  Future<int> getTotalUnreadCount() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return 0;

      final response = await _supabase
          .from('conversations')
          .select()
          .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId');

      int totalUnread = 0;
      for (var conv in (response as List)) {
        if (conv['user1_id'] == currentUserId) {
          totalUnread += (conv['user1_unread_count'] as int?) ?? 0;
        } else {
          totalUnread += (conv['user2_unread_count'] as int?) ?? 0;
        }
      }

      return totalUnread;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // Subscribe to new messages in a conversation
  Stream<MessageData> subscribeToMessages(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .asyncMap((messages) async {
          if (messages.isEmpty) return null;

          final latestMessage = messages.last;
          final senderProfile =
              await _supabase
                  .from('profiles')
                  .select()
                  .eq('id', latestMessage['sender_id'])
                  .single();

          latestMessage['sender_profile'] = senderProfile;
          return MessageData.fromJson(latestMessage);
        })
        .where((message) => message != null)
        .cast<MessageData>();
  }

  // Subscribe to conversation updates
  Stream<List<ConversationData>> subscribeToConversations() {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return Stream.value([]);

    return _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .asyncMap((conversations) async {
          final conversationList = <ConversationData>[];

          for (var conv in conversations) {
            // Manually filter: only include conversations where current user is a participant
            if (conv['user1_id'] == currentUserId ||
                conv['user2_id'] == currentUserId) {
              final otherUserId =
                  conv['user1_id'] == currentUserId
                      ? conv['user2_id']
                      : conv['user1_id'];

              try {
                final profileResponse =
                    await _supabase
                        .from('profiles')
                        .select()
                        .eq('id', otherUserId)
                        .single();

                conv['other_user_profile'] = profileResponse;
                conversationList.add(
                  ConversationData.fromJson(conv, currentUserId),
                );
              } catch (e) {
                print('Error fetching profile for conversation: $e');
              }
            }
          }

          return conversationList;
        });
  }
}
