# 🔧 Fix Like and Comment Counts

## 🐛 **Issues:**

1. **Comment count doesn't update** after commenting
2. **Like count doesn't persist** after refresh (shows liked, but count is wrong)

---

## ✅ **Root Cause:**

The issue is that like/comment counts are stored in **local state** but not properly refreshed from the database.

### **What's happening:**
```
1. User likes post
2. Local state: likes_count++ (increases)
3. Database: Updated correctly
4. User refreshes
5. Fetches from database
6. BUT: Using old cached count ❌
```

---

## 🔧 **Solution: Refresh from ContentProvider**

### **Step 1: After Like, Refresh Data**

In your like handler (in `main.dart` or wherever PostCard is):

```dart
Future<void> _handleLike(String postId) async {
  try {
    // Update like in database
    await Supabase.instance.client
        .from('likes')
        .insert({'post_id': postId, 'user_id': currentUserId});
    
    // IMPORTANT: Refresh the post data from database
    await Provider.of<ContentProvider>(context, listen: false).refreshData();
    
  } catch (e) {
    print('Error liking post: $e');
  }
}
```

### **Step 2: After Comment, Refresh Data**

When returning from CommentsScreen:

```dart
await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CommentsScreen(postId: post.id),
  ),
);

// IMPORTANT: Refresh after returning from comments
await Provider.of<ContentProvider>(context, listen: false).refreshData();
```

---

## 📊 **Alternative: Optimistic Updates with Database Sync**

If you want instant feedback without waiting:

### **For Likes:**

```dart
Future<void> _handleLike(String postId) async {
  // Get current post
  final postIndex = posts.indexWhere((p) => p.id == postId);
  if (postIndex == -1) return;
  
  final post = posts[postIndex];
  final isLiked = post.isLiked ?? false;
  
  // Optimistic update
  setState(() {
    post.likesCount = (post.likesCount ?? 0) + (isLiked ? -1 : 1);
    post.isLiked = !isLiked;
  });
  
  try {
    if (isLiked) {
      // Unlike
      await Supabase.instance.client
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', currentUserId);
    } else {
      // Like
      await Supabase.instance.client
          .from('likes')
          .insert({'post_id': postId, 'user_id': currentUserId});
    }
    
    // Sync with database to get real count
    final realCount = await Supabase.instance.client
        .from('posts')
        .select('likes_count')
        .eq('id', postId)
        .single();
    
    setState(() {
      post.likesCount = realCount['likes_count'];
    });
    
  } catch (e) {
    // Revert on error
    setState(() {
      post.likesCount = (post.likesCount ?? 0) + (isLiked ? 1 : -1);
      post.isLiked = isLiked;
    });
  }
}
```

### **For Comments:**

```dart
// In CommentsScreen, after posting comment:
await Supabase.instance.client
    .from('comments')
    .insert({
      'post_id': postId,
      'user_id': currentUserId,
      'text': commentText,
    });

// Update comment count in posts table
await Supabase.instance.client.rpc('increment_comment_count', params: {
  'post_id': postId,
});

// Or manually:
final currentCount = await Supabase.instance.client
    .from('posts')
    .select('comments_count')
    .eq('id', postId)
    .single();

await Supabase.instance.client
    .from('posts')
    .update({'comments_count': (currentCount['comments_count'] ?? 0) + 1})
    .eq('id', postId);
```

---

## 🗄️ **Database Fix: Use Triggers (Best Practice)**

Create SQL functions to auto-update counts:

```sql
-- Function to update likes count
CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts 
    SET likes_count = likes_count + 1 
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts 
    SET likes_count = GREATEST(likes_count - 1, 0) 
    WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for likes
DROP TRIGGER IF EXISTS trigger_update_likes_count ON likes;
CREATE TRIGGER trigger_update_likes_count
  AFTER INSERT OR DELETE ON likes
  FOR EACH ROW
  EXECUTE FUNCTION update_post_likes_count();

-- Function to update comments count
CREATE OR REPLACE FUNCTION update_post_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts 
    SET comments_count = comments_count + 1 
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts 
    SET comments_count = GREATEST(comments_count - 1, 0) 
    WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for comments
DROP TRIGGER IF EXISTS trigger_update_comments_count ON comments;
CREATE TRIGGER trigger_update_comments_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW
  EXECUTE FUNCTION update_post_comments_count();
```

---

## 🎯 **Quick Fix (Easiest):**

### **Add this after every like/comment action:**

```dart
// After liking/unliking
await Provider.of<ContentProvider>(context, listen: false).refreshData();

// After commenting (when returning from CommentsScreen)
await Provider.of<ContentProvider>(context, listen: false).refreshData();
```

This ensures the UI always shows correct counts from the database.

---

## 📱 **Expected Flow:**

### **Liking:**
```
1. Tap like button
2. Send to database
3. Refresh ContentProvider
4. UI shows updated count ✅
5. Refresh page
6. Count still correct ✅
```

### **Commenting:**
```
1. Open CommentsScreen
2. Post comment
3. Return to feed
4. Refresh ContentProvider
5. Comment count updated ✅
```

---

## 🧪 **Test:**

1. **Like a post** → Count increases ✅
2. **Refresh feed** → Count stays same ✅
3. **Unlike post** → Count decreases ✅
4. **Comment on post** → Count increases ✅
5. **Refresh feed** → Count persists ✅

---

## 💡 **Best Practice:**

1. **Use database triggers** (SQL above) - Auto-updates counts
2. **Refresh after actions** - Ensures UI sync
3. **Optimistic updates** - Better UX (instant feedback)
4. **Sync with database** - Verify correct counts

---

**The easiest fix: Add `refreshData()` after like/comment actions!**
