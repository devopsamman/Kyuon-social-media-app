-- SQL script to fix comment counts in videos table
-- This will sync the comment counts with actual comments in video_comments table
-- Run this in your Supabase SQL Editor

-- Update all videos to have correct comment count based on actual comments
UPDATE public.videos
SET comments = (
    SELECT COUNT(*)
    FROM public.video_comments
    WHERE video_comments.video_id = videos.id
);

-- Verify the fix - this will show you the counts
SELECT 
    v.id,
    v.comments as stored_count,
    COUNT(vc.id) as actual_count,
    (v.comments = COUNT(vc.id)) as is_synced
FROM public.videos v
LEFT JOIN public.video_comments vc ON vc.video_id = v.id
GROUP BY v.id, v.comments
ORDER BY v.comments DESC;

-- Optional: Create a trigger to keep counts in sync automatically
-- This will update the comment count whenever a comment is inserted or deleted

-- Function to update comment count
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

-- Create trigger
CREATE TRIGGER sync_video_comment_count
    AFTER INSERT OR DELETE ON public.video_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_video_comment_count();

-- Now do the same for posts
UPDATE public.posts
SET comments = (
    SELECT COUNT(*)
    FROM public.comments
    WHERE comments.post_id = posts.id
);

-- Verify posts
SELECT 
    p.id,
    p.comments as stored_count,
    COUNT(c.id) as actual_count,
    (p.comments = COUNT(c.id)) as is_synced
FROM public.posts p
LEFT JOIN public.comments c ON c.post_id = p.id
GROUP BY p.id, p.comments
ORDER BY p.comments DESC;

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

-- Create trigger
CREATE TRIGGER sync_post_comment_count
    AFTER INSERT OR DELETE ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION update_post_comment_count();

-- Success message
SELECT 'Comment counts have been synced! Triggers installed for automatic sync.' as status;
