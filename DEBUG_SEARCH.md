# 🐛 Debug: Posts and Reels Not Showing

## 🔍 **Debugging Steps:**

### **Step 1: Check Console Logs**

After searching, you should see in the console:

```
🔍 Searching for: "your_query"
🔍 Searching posts for: "your_query"
📊 Posts response type: _GrowableList<dynamic>
📊 Posts response: [...]
✅ Found X posts

🔍 Searching reels for: "your_query"  
📊 Reels response type: _GrowableList<dynamic>
📊 Reels response: [...]
✅ Found X reels
```

### **Step 2: If You See Errors**

**Error: "function search_posts does not exist"**
→ SQL not run correctly in Supabase
→ Re-run `setup_search.sql`

**Error: "column does not exist"**
→ Check your database schema
→ Ensure columns match (content, image_url, etc.)

**Response is null or empty []**
→ No data matches your search
→ Try searching for something you know exists

---

## 🧪 **Test with Sample Data:**

### **1. Check if you have posts:**
```sql
-- Run in Supabase SQL Editor
SELECT COUNT(*) FROM posts;
```

If 0, you need to create posts first!

### **2. Check if you have reels:**
```sql
SELECT COUNT(*) FROM videos;
```

If 0, you need to upload reels first!

### **3. Test search function directly:**
```sql
-- Test search_posts
SELECT * FROM search_posts('test', 10);

-- Test search_reels
SELECT * FROM search_reels('test', 10);
```

Should return some results if data exists.

---

## 🔧 **Common Issues:**

### **Issue 1: Empty Database**
**Symptom:** No results for any search
**Solution:** Add some posts and reels first

### **Issue 2: Wrong Column Names**
**Symptom:** Error in console about columns
**Solution:** Check your posts/videos table structure

### **Issue 3: Functions Not Created**
**Symptom:** "function does not exist"
**Solution:** Re-run setup_search.sql

### **Issue 4: Null Results**
**Symptom:** Console shows "null" or "[]"
**Solution:** Search for content that actually exists

---

## 📊 **Verify Your Data:**

### **Check Posts Table:**
```sql
SELECT id, content, image_url FROM posts LIMIT 5;
```

Should show some posts with content.

### **Check Videos Table:**
```sql
SELECT id, title, video_url FROM videos LIMIT 5;
```

Should show some reels with titles.

### **Check if Search Works:**
```sql
-- Search for a specific word you know exists
SELECT * FROM search_posts('your_known_word', 10);
```

---

## 🎯 **Quick Fix Checklist:**

- [ ] SQL ran successfully (no errors)
- [ ] Database has posts (SELECT COUNT(*) FROM posts)
- [ ] Database has reels (SELECT COUNT(*) FROM videos)
- [ ] Searching for content that exists
- [ ] Console shows debug logs
- [ ] No errors in console

---

## 💡 **Next Steps:**

1. **Restart the app** (hot reload may not be enough)
2. **Check console** for the debug logs
3. **Try searching** for something specific
4. **Share console output** if still not working

---

**The debug logs will tell us exactly what's happening!**
