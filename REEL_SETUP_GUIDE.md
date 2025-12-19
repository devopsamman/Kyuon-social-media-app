# 🎯 CRITICAL: Reel Likes & Comments Setup Guide

## ✅ What We Fixed

### 1. **Proper Like System**
- ✅ Created `video_likes` table to track user likes
- ✅ Prevents duplicate likes (one user = one like per reel)
- ✅ Likes persist across app sessions
- ✅ Like count now accurate and synced with database
- ✅ Heart animation shows on both double-tap AND like button tap

### 2. **Proper Comment System**
- ✅ Created `video_comments` table for reel comments
- ✅ Comments properly linked to videos table (not posts)
- ✅ Full-screen comment interface with keyboard handling

### 3. **UI/UX Improvements**
- ✅ Like/comment counts display on reel videos
- ✅ Double-tap heart animation working
- ✅ Red heart icon when reel is liked
- ✅ Smooth animations and visual feedback

---

## 🚨 REQUIRED: Run These SQL Scripts

You **MUST** run these SQL scripts in your Supabase dashboard for the features to work:

### Step 1: Create video_likes Table

1. Open Supabase Dashboard → SQL Editor
2. Copy and paste this:

```sql
-- Create video_likes table
CREATE TABLE IF NOT EXISTS public.video_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(video_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_video_likes_video_id ON public.video_likes(video_id);
CREATE INDEX IF NOT EXISTS idx_video_likes_user_id ON public.video_likes(user_id);

ALTER TABLE public.video_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Video likes are viewable by everyone" 
    ON public.video_likes FOR SELECT 
    USING (true);

CREATE POLICY "Users can insert their own video likes" 
    ON public.video_likes FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own video likes" 
    ON public.video_likes FOR DELETE 
    USING (auth.uid() = user_id);

GRANT ALL ON public.video_likes TO authenticated;
GRANT SELECT ON public.video_likes TO anon;
```

3. Click **Run**

---

### Step 2: Create video_comments Table

1. In the same SQL Editor, run this:

```sql
-- Create video_comments table
CREATE TABLE IF NOT EXISTS public.video_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_video_comments_video_id ON public.video_comments(video_id);
CREATE INDEX IF NOT EXISTS idx_video_comments_user_id ON public.video_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_video_comments_created_at ON public.video_comments(created_at DESC);

ALTER TABLE public.video_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Video comments are viewable by everyone" 
    ON public.video_comments FOR SELECT 
    USING (true);

CREATE POLICY "Users can insert their own video comments" 
    ON public.video_comments FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own video comments" 
    ON public.video_comments FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own video comments" 
    ON public.video_comments FOR DELETE 
    USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION update_video_comments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_video_comments_updated_at
    BEFORE UPDATE ON public.video_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_video_comments_updated_at();

GRANT ALL ON public.video_comments TO authenticated;
GRANT SELECT ON public.video_comments TO anon;
```

2. Click **Run**

---

## ✨ What Will Work After Running SQL

### ✅ Liking Reels
- Double-tap on video → ❤️ animat + like
- Tap like button → ❤️ animation + like
- Like icon turns **red** when liked
- Like count updates immediately
- Can only like once per reel (database enforced)
- Likes persist across app restarts

### ✅ Commenting on Reels
- Tap comment button → Opens full-screen comments
- Write comment → Saves to database
- Comment count shows on reel
- Comments load from database
- Keyboard handling works properly

### ✅ Counts Display
- Like count shows on reel (e.g., "1.2K", "523", "2.5M")
- Comment count shows on reel

---

## 🐛 Current Errors You're Seeing

### Error 1: "table 'public.video_likes' not found"
**Cause:** video_likes table doesn't exist yet  
**Fix:** Run Step 1 SQL script above

### Error 2: "table 'public.video_comments' not found"  
**Cause:** video_comments table doesn't exist yet  
**Fix:** Run Step 2 SQL script above

---

## 📱 Testing After Setup

1. **Run the SQL scripts** (both Step 1 and Step 2)
2. **Restart your app**
3. **Test likes:**
   - Double-tap a reel video → Should show heart animation
   - Tap like button → Should show heart animation
   - Icon should turn red
   - Like count should increase
   - Try liking again → Should not allow (already liked)
4. **Test comments:**
   - Tap comment button
   - Write a comment
   - Submit
   - Comment should appear
   - Comment count should increase

---

## 📁 Files Modified

- ✅ `lib/services/supabase_service.dart` - Added like/unlike/comment methods
- ✅ `lib/services/content_provider.dart` - Added liked reels tracking
- ✅ `lib/screens/comments_screen.dart` - Added reel comment support
- ✅ `lib/main.dart` - Updated reel UI to use provider's liked state
- ✅ `lib/models/reel_data.dart` - Already has id and avatarUrl

---

## 🎉 Summary

After running both SQL scripts:
1. ✅ Likes work properly (no duplicates)
2. ✅ Comments work properly (uses video_comments table)
3. ✅ Counts display correctly
4. ✅ Double-tap heart animation works
5. ✅ Like button heart animation works
6. ✅ Everything persists across app sessions

**Total time to setup:** ~2 minutes  
**SQL scripts to run:** 2  
**Result:** Fully functional Instagram-like reel system! 🚀
