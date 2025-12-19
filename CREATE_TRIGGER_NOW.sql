-- SIMPLE FIX: Create trigger to auto-update comment counts
-- Copy this entire script and run in Supabase SQL Editor NOW

-- Clean up any existing trigger
DROP TRIGGER IF EXISTS sync_video_comment_count ON public.video_comments CASCADE;
DROP FUNCTION IF EXISTS update_video_comment_count() CASCADE;

-- Create the function that updates counts
CREATE FUNCTION update_video_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- When comment inserted, increment count
        UPDATE public.videos
        SET comments = comments + 1
        WHERE id = NEW.video_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- When comment deleted, decrement count
        UPDATE public.videos
        SET comments = GREATEST(comments - 1, 0)
        WHERE id = OLD.video_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER sync_video_comment_count
    AFTER INSERT OR DELETE ON public.video_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_video_comment_count();

-- Fix existing counts
UPDATE public.videos
SET comments = (
    SELECT COUNT(*)
    FROM public.video_comments
    WHERE video_comments.video_id = videos.id
);

-- Done!
SELECT 'Trigger created! Comments will now auto-update counts.' as status;
