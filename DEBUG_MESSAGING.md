# 🐛 Debugging Messaging Issues

## ✅ **Debug Checklist**

Follow these steps to find and fix the issue:

---

## **Step 1: Verify SQL Tables Were Created**

### **Check in Supabase Dashboard:**

1. Go to: https://supabase.com/dashboard
2. Select your project
3. Click "Table Editor" in sidebar
4. Look for these tables:
   - ✅ `conversations`
   - ✅ `messages`

### **If tables don't exist:**
```sql
-- Run this in SQL Editor
-- Copy from create_messaging_tables.sql and run it
```

---

## **Step 2: Check Console Logs**

### **What to look for:**

Open your app and watch the console. You should see:

```
📤 Sending message to conversation: [conversation-id]
✅ Message sent successfully

🔄 Polling for new messages in conversation: [conversation-id]
📊 Current: 0 messages, Latest: 1 messages
🆕 New message found: "Hello" from User
✅ Updating chat with 1 messages
```

### **If you see errors:**

**Error: "relation messages does not exist"**
→ SQL tables not created. Run `create_messaging_tables.sql`

**Error: "permission denied"**
→ RLS policies not set up. Check SQL file

**No polling logs:**
→ Check if chat screen is actually open

---

## **Step 3: Test Database Directly**

### **In Supabase SQL Editor, run:**

```sql
-- 1. Check if conversations exist
SELECT * FROM conversations;

-- 2. Check if messages exist
SELECT * FROM messages;

-- 3. Check if your message was saved
SELECT 
  m.id,
  m.message_text,
  m.created_at,
  p.username as sender
FROM messages m
LEFT JOIN profiles p ON m.sender_id = p.id
ORDER BY m.created_at DESC
LIMIT 10;
```

### **What you should see:**
- Conversations table has a row for your chat
- Messages table has your sent messages
- Message text matches what you sent

---

## **Step 4: Test Conversation Creation**

### **Send a test message and check logs:**

```
Device 1: "Test message"
    ↓
Look for:
🔄 Getting or creating conversation with: [user-id]
✅ Conversation ID: [conversation-id]
📤 Sending message to conversation: [conversation-id]
✅ Message sent successfully
```

### **If conversation creation fails:**
- Check if `get_or_create_conversation` function exists
- Run the SQL from `create_messaging_tables.sql`

---

## **Step 5: Verify Both Devices Are in Same Conversation**

### **Check conversation IDs match:**

Device 1 console:
```
Conversation ID: abc-123-xyz
```

Device 2 console:
```
Conversation ID: abc-123-xyz  ← Should be SAME!
```

### **If IDs are different:**
- Conversation not created correctly
- Check `get_or_create_conversation` function

---

## **Step 6: Check Polling**

### **On Device 2 (receiver), watch console:**

Every 3 seconds you should see:
```
🔄 Polling for new messages in conversation: [id]
📊 Current: 0 messages, Latest: 0 messages
ℹ️ No new messages
```

Then after Device 1 sends:
```
🔄 Polling for new messages in conversation: [id]
📊 Current: 0 messages, Latest: 1 messages
🆕 New message found: "Hello" from User1
✅ Updating chat with 1 messages
```

### **If no polling logs:**
- Chat screen might not be open
- Timer might not be running
- Check app isn't crashed

---

## **Step 7: Test with SQL Insert**

### **Manually insert a message in Supabase:**

```sql
-- Get your conversation ID from conversations table
SELECT id FROM conversations LIMIT 1;

-- Insert a test message
INSERT INTO messages (
  conversation_id,
  sender_id,
  receiver_id,
  message_text
) VALUES (
  'YOUR_CONVERSATION_ID',  -- Replace with actual ID
  'USER1_ID',              -- Replace with sender ID
  'USER2_ID',              -- Replace with receiver ID
  'Test from database'
);
```

### **Result:**
- Message should appear in chat within 3 seconds
- If it does, app is working!

---

## **Step 8: Check Message Fetch**

### **Add this to messaging_service.dart temporarily:**

```dart
Future<List<MessageData>> getMessages(String conversationId) async {
  print('🔍 Fetching messages for conversation: $conversationId');
  
  final response = await _supabase
      .from('messages')
      .select()
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: true);

  print('🔍 Raw response: $response');
  print('🔍 Found ${(response as List).length} messages');
  
  // ... rest of code
}
```

---

## **Common Issues & Solutions**

### **Issue 1: Messages not saving**
**Solution:**
- Check SQL tables exist
- Verify RLS policies allow insert
- Look for errors in console

### **Issue 2: Messages not appearing**
**Solution:**
- Check polling is running (look for logs)
- Verify both devices in same conversation
- Check message fetch returns data

### **Issue 3: Different conversation IDs**
**Solution:**
- Check `get_or_create_conversation` function
- Verify it sorts user IDs correctly
- Re-run SQL to create function

### **Issue 4: Permission errors**
**Solution:**
- Check RLS policies in SQL
- Verify user is authenticated
- Check auth.uid() matches

---

## **Quick Test Script**

### **Run this to verify everything:**

1. **Device 1:** Open chat with User B
2. **Device 2:** Open chat with User A
3. **Both devices:** Watch console logs
4. **Device 1:** Send "Test 1"
5. **Wait 3 seconds**
6. **Device 2:** Should show "Test 1" ✅
7. **Device 2:** Send "Test 2"
8. **Wait 3 seconds**
9. **Device 1:** Should show "Test 2" ✅

---

## **Expected Console Flow**

### **Device 1 (Sender):**
```
🔄 Opening chat with user: [user-b-id]
✅ Conversation ID: abc-123
📥 Fetching messages for conversation: abc-123
✅ Fetched 0 messages
🔄 Polling for new messages in conversation: abc-123
📊 Current: 0 messages, Latest: 0 messages

[User types "Hello" and sends]

📤 Sending message to conversation: abc-123
✅ Message sent successfully
🔄 Polling for new messages in conversation: abc-123
📊 Current: 1 messages, Latest: 1 messages
```

### **Device 2 (Receiver):**
```
🔄 Opening chat with user: [user-a-id]
✅ Conversation ID: abc-123  ← Same ID!
📥 Fetching messages for conversation: abc-123
✅ Fetched 0 messages
🔄 Polling for new messages in conversation: abc-123
📊 Current: 0 messages, Latest: 0 messages

[Wait ~3 seconds after Device 1 sent]

🔄 Polling for new messages in conversation: abc-123
📊 Current: 0 messages, Latest: 1 messages
🆕 New message found: "Hello" from UserA
✅ Updating chat with 1 messages
✔️ Marking messages as read
✅ Messages marked as read
```

---

## **Still Not Working?**

### **Share these logs:**
1. Full console output from both devices
2. SQL query results from Step 3
3. Conversation IDs from both devices
4. Any error messages

---

**Most likely issue:** SQL tables not created. Run `create_messaging_tables.sql` first!
