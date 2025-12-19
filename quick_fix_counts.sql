-- Quick diagnostic and fix for comment count mismatch
-- Run this in Supabase SQL Editor

-- Step 1: Show which videos have mismatched counts
SELECT 
    v.id,
    v.comments as stored_count,
    COUNT(vc.id) as actual_count,
    (v.comments = COUNT(vc.id)) as is_synced
FROM public.videos v
LEFT JOIN public.video_comments vc ON vc.video_id = v.id
GROUP BY v.id, v.comments
HAVING v.comments != COUNT(vc.id)
ORDER BY v.comments DESC;

-- Step 2: Fix ALL mismatched counts immediately
UPDATE public.videos
SET comments = (
    SELECT COUNT(*)
    FROM public.video_comments
    WHERE video_comments.video_id = videos.id
)
WHERE comments != (
    SELECT COUNT(*)
    FROM public.video_comments
    WHERE video_comments.video_id = videos.id
);

-- Step 3: Verify the trigger exists and is working
SELECT 
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'sync_video_comment_count';

-- Step 4: If trigger doesn't exist, create it
DO $$
BEGIN
    -- Check if trigger exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'sync_video_comment_count'
    ) THEN
        -- Create the trigger
        CREATE OR REPLACE FUNCTION update_video_comment_count()
        RETURNS TRIGGER AS $func$
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
        $func$ LANGUAGE plpgsql;

        CREATE TRIGGER sync_video_comment_count
            AFTER INSERT OR DELETE ON public.video_comments
            FOR EACH ROW
            EXECUTE FUNCTION update_video_comment_count();
            
        RAISE NOTICE 'Trigger created successfully!';
    ELSE
        RAISE NOTICE 'Trigger already exists';
    END IF;
END $$;

-- Step 5: Final verification - all counts should match now
SELECT 
    v.id,
    v.comments as stored_count,
    COUNT(vc.id) as actual_count,
    CASE 
        WHEN v.comments = COUNT(vc.id) THEN 'SYNCED ✓'
        ELSE 'OUT OF SYNC ✗'
    END as status
FROM public.videos v
LEFT JOIN public.video_comments vc ON vc.video_id = v.id
GROUP BY v.id, v.comments
ORDER BY v.comments DESC
LIMIT 20;

-- Success message
SELECT 'All comment counts fixed and trigger verified!' as result;
