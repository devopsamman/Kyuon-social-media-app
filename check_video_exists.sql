-- Diagnostic: Check if video exists and verify IDs match
-- Run this in Supabase SQL Editor

-- Step 1: Show all videos with their IDs
SELECT id, comments, likes
FROM public.videos
ORDER BY comments DESC
LIMIT 10;

-- Step 2: Check if there are orphaned comments (comments with no matching video)
SELECT 
    vc.video_id,
    COUNT(*) as comment_count,
    CASE 
        WHEN v.id IS NULL THEN '✗ VIDEO MISSING'
        ELSE '✓ Video exists'
    END as status
FROM public.video_comments vc
LEFT JOIN public.videos v ON v.id = vc.video_id
GROUP BY vc.video_id, v.id
ORDER BY comment_count DESC;

-- Step 3: Show videos that have comments
SELECT 
    v.id,
    v.comments as stored_count,
    COUNT(vc.id) as actual_comments
FROM public.videos v
LEFT JOIN public.video_comments vc ON vc.video_id = v.id
GROUP BY v.id
HAVING COUNT(vc.id) > 0
ORDER BY actual_comments DESC;

-- Step 4: Try to fix - add missing videos if needed
-- First, find video IDs that have comments but no video entry
SELECT DISTINCT video_id
FROM public.video_comments
WHERE video_id NOT IN (SELECT id FROM public.videos);

-- If you see IDs above, you need to create video entries for them
-- Tell me the IDs and I'll help create the insert statement
