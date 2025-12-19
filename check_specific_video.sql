-- Check if the specific video exists
-- Replace VIDEO_ID with your actual video ID from console

-- Check if video exists
SELECT id, comments, likes, created_at
FROM public.videos 
WHERE id = '260cb041-1c9f-4876-b82d-1fa92d817741';

-- If the above returns nothing, check all videos
SELECT id, comments, likes
FROM public.videos
LIMIT 20;

-- Check comments for that video
SELECT COUNT(*) as total_comments
FROM public.video_comments
WHERE video_id = '260cb041-1c9f-4876-b82d-1fa92d817741';

-- Check if there's a mismatch
SELECT 
    vc.video_id,
    COUNT(vc.id) as actual_comments,
    v.comments as stored_comments,
    CASE 
        WHEN v.id IS NULL THEN '❌ VIDEO DOES NOT EXIST'
        WHEN v.comments = COUNT(vc.id) THEN '✅ SYNCED'
        ELSE '⚠️ MISMATCH'
    END as status
FROM public.video_comments vc
LEFT JOIN public.videos v ON v.id = vc.video_id
WHERE vc.video_id = '260cb041-1c9f-4876-b82d-1fa92d817741'
GROUP BY vc.video_id, v.id, v.comments;
