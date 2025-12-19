-- SQL script to fix BOTH like and comment counts
-- This will sync everything and add triggers for automatic updates
-- Run this in your Supabase SQL Editor

-- ====================
-- FIX LIKE COUNTS
-- ====================

-- Update all videos to have correct like count based on actual likes
UPDATE public.videos
SET likes = (
    SELECT COUNT(*)
    FROM public.video_likes
    WHERE video_likes.video_id = videos.id
);

-- Function to update video like count
CREATE OR REPLACE FUNCTION update_video_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.videos
        SET likes = likes + 1
        WHERE id = NEW.video_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.videos
        SET likes = GREATEST(likes - 1, 0)
        WHERE id = OLD.video_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS sync_video_like_count ON public.video_likes;

-- Create trigger for video likes
CREATE TRIGGER sync_video_like_count
    AFTER INSERT OR DELETE ON public.video_likes
    FOR EACH ROW
    EXECUTE FUNCTION update_video_like_count();

-- ====================
-- FIX COMMENT COUNTS
-- ====================

-- Update all videos to have correct comment count
UPDATE public.videos
SET comments = (
    SELECT COUNT(*)
    FROM public.video_comments
    WHERE video_comments.video_id = videos.id
);

-- Function to update video comment count
CREATE OR REPLACE FUNCTION update_video_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.videos
        SET comments = comments + 1
        WHERE id = NEW.video_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.videos
        SET comments = GREATEST(comments - 1, 0)
        WHERE id = OLD.video_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS sync_video_comment_count ON public.video_comments;

-- Create trigger for video comments
CREATE TRIGGER sync_video_comment_count
    AFTER INSERT OR DELETE ON public.video_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_video_comment_count();

-- ====================
-- FIX POST LIKES
-- ====================

-- Update all posts to have correct like count
UPDATE public.posts
SET likes = (
    SELECT COUNT(*)
    FROM public.post_likes
    WHERE post_likes.post_id = posts.id
);

-- Function to update post like count
CREATE OR REPLACE FUNCTION update_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts
        SET likes = likes + 1
        WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts
        SET likes = GREATEST(likes - 1, 0)
        WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS sync_post_like_count ON public.post_likes;

-- Create trigger for post likes
CREATE TRIGGER sync_post_like_count
    AFTER INSERT OR DELETE ON public.post_likes
    FOR EACH ROW
    EXECUTE FUNCTION update_post_like_count();

-- ====================
-- FIX POST COMMENTS
-- ====================

-- Update all posts to have correct comment count
UPDATE public.posts
SET comments = (
    SELECT COUNT(*)
    FROM public.comments
    WHERE comments.post_id = posts.id
);

-- Function to update post comment count
CREATE OR REPLACE FUNCTION update_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts
        SET comments = comments + 1
        WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts
        SET comments = GREATEST(comments - 1, 0)
        WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS sync_post_comment_count ON public.comments;

-- Create trigger for post comments
CREATE TRIGGER sync_post_comment_count
    AFTER INSERT OR DELETE ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION update_post_comment_count();

-- ====================
-- VERIFICATION
-- ====================

-- Verify video likes
SELECT 
    v.id,
    v.likes as stored_likes,
    COUNT(vl.id) as actual_likes,
    (v.likes = COUNT(vl.id)) as likes_synced
FROM public.videos v
LEFT JOIN public.video_likes vl ON vl.video_id = v.id
GROUP BY v.id, v.likes
ORDER BY v.likes DESC
LIMIT 10;

-- Verify video comments
SELECT 
    v.id,
    v.comments as stored_comments,
    COUNT(vc.id) as actual_comments,
    (v.comments = COUNT(vc.id)) as comments_synced
FROM public.videos v
LEFT JOIN public.video_comments vc ON vc.video_id = v.id
GROUP BY v.id, v.comments
ORDER BY v.comments DESC
LIMIT 10;

-- Success message
SELECT 'All counts synced! Triggers installed for likes AND comments!' as status;
