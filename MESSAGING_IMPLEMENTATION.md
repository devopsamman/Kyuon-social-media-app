# 💬 Messaging System Implementation Guide

## 📋 **Overview**
Complete Instagram-style direct messaging system with:
- Real-time messages
- Unread counts
- Read receipts
- Conversation list
- Individual chat screens

---

## 🗄️ **Step 1: Database Setup**

### Run SQL in Supabase:
1. Go to your Supabase Dashboard
2. Navigate to SQL Editor
3. Copy and run `create_messaging_tables.sql`
4. Verify tables created:
   - `conversations`
   - `messages`

### What it creates:
- ✅ Conversations table (stores chat threads)
- ✅ Messages table (stores individual messages)
- ✅ Auto-updating unread counts
- ✅ Real-time subscriptions enabled
- ✅ RLS policies for security
- ✅ Helper functions for common operations

---

## 📱 **Step 2: Flutter Implementation**

### Files to Create:

1. **`lib/models/message_data.dart`** ✅ (Already created)
   - ConversationData model
   - MessageData model

2. **`lib/screens/messages_screen.dart`** (List of conversations)
   - Shows all chats
   - Unread badges
   - Last message preview

3. **`lib/screens/chat_screen.dart`** (Individual conversation)
   - Message bubbles
   - Send messages
   - Real-time updates
   - Read receipts

4. **`lib/services/messaging_service.dart`** (Backend logic)
   - Fetch conversations
   - Send messages
   - Mark as read
   - Real-time listeners

---

## 🎨 **Step 3: UI Changes**

### Update HomeFeedScreen AppBar:
```dart
// Replace 3 dots icon with message icon
IconButton(
  icon: Stack(
    children: [
      const Icon(Icons.message),
      // Unread badge
      if (unreadCount > 0)
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$unreadCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        ),
    ],
  ),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MessagesScreen(),
      ),
    );
  },
)
```

---

## 🔄 **Step 4: Messaging Service**

### Core Functions:

1. **Get Conversations**
   ```dart
   Future<List<ConversationData>> getConversations()
   ```

2. **Get Messages**
   ```dart
   Future<List<MessageData>> getMessages(String conversationId)
   ```

3. **Send Message**
   ```dart
   Future<void> sendMessage(String receiverId, String text)
   ```

4. **Mark as Read**
   ```dart
   Future<void> markAsRead(String conversationId)
   ```

5. **Subscribe to Real-time**
   ```dart
   Stream<MessageData> subscribeToMessages(String conversationId)
   ```

---

## 🚀 **Step 5: Start a Chat**

### From OtherUserProfileScreen:
Add a message button next to the follow button:

```dart
IconButton(
  icon: const Icon(Icons.message),
  onPressed: () async {
    // Get or create conversation
    final conversationId = await MessagingService()
        .getOrCreateConversation(widget.userId);
    
    // Navigate to chat
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversationId,
          otherUserId: widget.userId,
        ),
      ),
    );
  },
)
```

---

## 📊 **Step 6: Real-time Updates**

### Enable in Supabase:
Database > Replication > Enable for:
- ✅ `messages` table
- ✅ `conversations` table

### In Flutter:
```dart
final subscription = supabase
    .from('messages')
    .stream(primaryKey: ['id'])
    .eq('conversation_id', conversationId)
    .listen((data) {
      // Update UI with new messages
    });
```

---

##  **Features Checklist**

### Core Features:
- ✅ List all conversations
- ✅ Show last message preview
- ✅ Unread count badges
- ✅ Send text messages
- ✅ Receive messages in real-time
- ✅ Mark messages as read
- ✅ Read receipts
- ✅ Message timestamps

### Advanced Features (Future):
- ⏳ Send images
- ⏳ Send videos
- ⏳ Voice messages
- ⏳ Message reactions
- ⏳ Delete messages
- ⏳ Message search
- ⏳ Typing indicators
- ⏳ Online status

---

## 🎯 **User Flow**

```
Home Feed
    ↓
Tap message icon (top right)
    ↓
Messages Screen (List of chats)
    ↓
Tap conversation
    ↓
Chat Screen
    ↓
Send/receive messages in real-time
```

**Alternative Start:**
```
Other User's Profile
    ↓
Tap message button
    ↓
Opens/creates conversation
    ↓
Chat Screen
```

---

## 🔐 **Security**

### Row Level Security (RLS):
- ✅ Users can only see their own conversations
- ✅ Users can only see messages they sent/received
- ✅ Users can only send messages as themselves
- ✅ Automatic permission checks on all operations

---

## 📝 **Next Steps**

1. **Run SQL** in Supabase ✅
2. **Create MessagingService** → I'll provide code
3. **Create MessagesScreen** → I'll provide code
4. **Create ChatScreen** → I'll provide code
5. **Update HomeFeedScreen** → Add message icon
6. **Update OtherUserProfileScreen** → Add message button
7. **Test** → Send messages, verify real-time updates

---

## 💡 **Tips**

- Messages auto-update with real-time subscriptions
- Unread counts auto-increment/decrement via triggers
- Conversations auto-sort by last message time
- All database operations are secure with RLS
- Use `get_or_create_conversation()` function to avoid duplicates

---

**Ready to implement? I'll create all the Flutter screens and services next!**
