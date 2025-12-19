-- Test if trigger is working and fix if not
-- Run this in Supabase SQL Editor

-- Step 1: Check if trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE trigger_name = 'sync_video_comment_count';

-- Step 2: Check if function exists
SELECT routine_name
FROM information_schema.routines
WHERE routine_name = 'update_video_comment_count'
AND routine_type = 'FUNCTION';

-- Step 3: Drop existing trigger and function (clean slate)
DROP TRIGGER IF EXISTS sync_video_comment_count ON public.video_comments;
DROP FUNCTION IF EXISTS update_video_comment_count();

-- Step 4: Create function
CREATE OR REPLACE FUNCTION update_video_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Increment comment count
        UPDATE public.videos
        SET comments = comments + 1
        WHERE id = NEW.video_id;
        
        RAISE NOTICE 'Comment count incremented for video: %', NEW.video_id;
        RETURN NEW;
        
    ELSIF TG_OP = 'DELETE' THEN
        -- Decrement comment count
        UPDATE public.videos
        SET comments = GREATEST(comments - 1, 0)
        WHERE id = OLD.video_id;
        
        RAISE NOTICE 'Comment count decremented for video: %', OLD.video_id;
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create trigger
CREATE TRIGGER sync_video_comment_count
    AFTER INSERT OR DELETE ON public.video_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_video_comment_count();

-- Step 6: Verify trigger was created
SELECT 
    'Trigger created: ' || trigger_name as status
FROM information_schema.triggers
WHERE trigger_name = 'sync_video_comment_count';

-- Step 7: Fix current counts to match actual comments
UPDATE public.videos
SET comments = (
    SELECT COUNT(*)
    FROM public.video_comments
    WHERE video_comments.video_id = videos.id
);

-- Step 8: Show current status
SELECT 
    v.id,
    v.comments as video_table_count,
    COUNT(vc.id) as actual_comments,
    CASE 
        WHEN v.comments = COUNT(vc.id) THEN '✓ SYNCED'
        ELSE '✗ MISMATCH'
    END as status
FROM public.videos v
LEFT JOIN public.video_comments vc ON vc.video_id = v.id
GROUP BY v.id
ORDER BY v.comments DESC
LIMIT 10;

-- Step 9: Test the trigger with a dummy comment (then we'll delete it)
-- Find a video to test with
DO $$
DECLARE
    test_video_id UUID;
    test_user_id UUID;
    initial_count INT;
    new_count INT;
BEGIN
    -- Get any video
    SELECT id INTO test_video_id FROM public.videos LIMIT 1;
    
    -- Get first user
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    IF test_video_id IS NOT NULL AND test_user_id IS NOT NULL THEN
        -- Get initial count
        SELECT comments INTO initial_count FROM public.videos WHERE id = test_video_id;
        RAISE NOTICE 'Initial count for test video: %', initial_count;
        
        -- Insert test comment
        INSERT INTO public.video_comments (video_id, user_id, content)
        VALUES (test_video_id, test_user_id, 'TEST COMMENT - WILL BE DELETED');
        
        -- Check new count
        SELECT comments INTO new_count FROM public.videos WHERE id = test_video_id;
        RAISE NOTICE 'New count after insert: %', new_count;
        
        -- Delete test comment
        DELETE FROM public.video_comments 
        WHERE video_id = test_video_id AND content = 'TEST COMMENT - WILL BE DELETED';
        
        -- Check count after delete
        SELECT comments INTO new_count FROM public.videos WHERE id = test_video_id;
        RAISE NOTICE 'Count after delete: %', new_count;
        
        IF new_count = initial_count THEN
            RAISE NOTICE '✓ TRIGGER IS WORKING CORRECTLY!';
        ELSE
            RAISE WARNING '✗ TRIGGER NOT WORKING! Count should be % but is %', initial_count, new_count;
        END IF;
    ELSE
        RAISE NOTICE 'No video or user found for testing';
    END IF;
END $$;

-- Success message
SELECT '✓ Trigger installed and tested! Try adding a comment now.' as result;
