import 'package:flutter/material.dart';
import 'dart:async';
import '../models/message_data.dart';
import '../services/messaging_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messagingService = MessagingService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<MessageData> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  StreamSubscription? _messageSubscription;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markMessagesAsRead();
    _subscribeToMessages();
    _startPolling(); // Fallback: poll for new messages every 3 seconds
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final messages = await _messagingService.getMessages(widget.conversationId);
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _markMessagesAsRead() async {
    await _messagingService.markMessagesAsRead(widget.conversationId);
  }

  void _subscribeToMessages() {
    _messageSubscription = _messagingService
        .subscribeToMessages(widget.conversationId)
        .listen((newMessage) {
          if (mounted && !_messages.any((m) => m.id == newMessage.id)) {
            setState(() {
              _messages.add(newMessage);
            });
            _scrollToBottom();
            _markMessagesAsRead();
          }
        });
  }

  // Polling fallback: check for new messages every 3 seconds
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      print('🔄 Polling for updates in conversation: ${widget.conversationId}');

      try {
        // Mark messages as read every poll (since chat is open)
        await _markMessagesAsRead();

        // Fetch latest messages
        final latestMessages = await _messagingService.getMessages(
          widget.conversationId,
        );

        print(
          '📊 Current: ${_messages.length} messages, Latest: ${latestMessages.length} messages',
        );

        bool shouldUpdate = false;

        // Check 1: New messages
        if (latestMessages.length != _messages.length) {
          shouldUpdate = true;
          print('🆕 Message count changed');
        }

        // Check 2: Read status changed
        if (!shouldUpdate && latestMessages.isNotEmpty) {
          for (
            int i = 0;
            i < latestMessages.length && i < _messages.length;
            i++
          ) {
            if (latestMessages[i].isRead != _messages[i].isRead) {
              shouldUpdate = true;
              print('👀 Read status changed for message $i');
              break;
            }
          }
        }

        // Update if anything changed
        if (shouldUpdate) {
          print('✅ Updating chat with ${latestMessages.length} messages');
          if (mounted) {
            setState(() {
              _messages = latestMessages;
            });
            _scrollToBottom();
            await _markMessagesAsRead();
          }
        } else {
          print('ℹ️ No updates');
        }
      } catch (e) {
        print('❌ Polling error: $e');
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear(); // Clear input immediately for instant feedback

    // Pause polling while sending to avoid race conditions
    _pollingTimer?.cancel();

    try {
      // Send message to database
      await _messagingService.sendMessage(
        conversationId: widget.conversationId,
        receiverId: widget.otherUserId,
        messageText: text,
      );

      print('✅ Message sent, reloading messages...');

      // Reload messages immediately to show the sent message
      final latestMessages = await _messagingService.getMessages(
        widget.conversationId,
      );

      if (mounted) {
        setState(() {
          _messages = latestMessages;
        });
        _scrollToBottom();
      }

      print('✅ Send complete, messages updated to ${latestMessages.length}');
    } catch (e) {
      print('❌ Send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }

      // Resume polling after send completes
      _startPolling();
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    // Convert UTC timestamp to IST (Indian Standard Time - UTC+5:30)
    final istTimestamp =
        timestamp.toLocal(); // Converts to device's local time (IST)

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      istTimestamp.year,
      istTimestamp.month,
      istTimestamp.day,
    );

    if (messageDate == today) {
      // Today - show time only in IST
      return '${istTimestamp.hour.toString().padLeft(2, '0')}:${istTimestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday - show time in IST
      return 'Yesterday ${istTimestamp.hour.toString().padLeft(2, '0')}:${istTimestamp.minute.toString().padLeft(2, '0')}';
    } else {
      // Older - show date
      return '${istTimestamp.day}/${istTimestamp.month}/${istTimestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  widget.otherUserAvatar.isNotEmpty
                      ? NetworkImage(widget.otherUserAvatar)
                      : null,
              backgroundColor: Colors.grey.shade300,
              child:
                  widget.otherUserAvatar.isEmpty
                      ? Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.grey.shade600,
                      )
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Send a message to start the conversation',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isSentByMe = message.isSentByMe(currentUserId);
                        // Show timestamp for first message or if 1+ hour passed since last message
                        final showTimestamp =
                            index == 0 ||
                            _messages[index - 1].createdAt
                                    .difference(message.createdAt)
                                    .inMinutes
                                    .abs() >=
                                60; // 1 hour = 60 minutes

                        return _buildMessageBubble(
                          message,
                          isSentByMe,
                          isDarkMode,
                          showTimestamp,
                        );
                      },
                    ),
          ),
          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
              border: Border(
                top: BorderSide(
                  color:
                      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color:
                              isDarkMode
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon:
                          _isSending
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    MessageData message,
    bool isSentByMe,
    bool isDarkMode,
    bool showTimestamp,
  ) {
    return Column(
      crossAxisAlignment:
          isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showTimestamp)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _formatMessageTime(message.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment:
                isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isSentByMe) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundImage:
                      widget.otherUserAvatar.isNotEmpty
                          ? NetworkImage(widget.otherUserAvatar)
                          : null,
                  backgroundColor: Colors.grey.shade300,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSentByMe
                            ? Theme.of(context).primaryColor
                            : (isDarkMode
                                ? Colors.grey.shade800
                                : Colors.grey.shade200),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isSentByMe ? 18 : 4),
                      bottomRight: Radius.circular(isSentByMe ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.messageText,
                        style: TextStyle(
                          fontSize: 15,
                          color:
                              isSentByMe
                                  ? Colors.white
                                  : (isDarkMode
                                      ? Colors.white
                                      : Colors.black87),
                        ),
                      ),
                      if (isSentByMe && message.isRead)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.done_all,
                                size: 12,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Seen',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
