-- Fix comment count mismatch
-- This will count actual comments and update the videos table
-- Run this in Supabase SQL Editor

-- Update ALL videos to have the correct comment count
UPDATE public.videos v
SET comments = (
    SELECT COUNT(*)
    FROM public.video_comments vc
    WHERE vc.video_id = v.id
);

-- Show the results to verify
SELECT 
    v.id,
    v.comments AS stored_count,
    COUNT(vc.id) AS actual_count,
    CASE 
        WHEN v.comments = COUNT(vc.id) THEN '✓ SYNCED'
        ELSE '✗ MISMATCH'
    END AS status
FROM public.videos v
LEFT JOIN public.video_comments vc ON vc.video_id = v.id
GROUP BY v.id
ORDER BY actual_count DESC
LIMIT 20;

-- Success message
SELECT 'All video comment counts are now synced with actual comments!' AS result;
