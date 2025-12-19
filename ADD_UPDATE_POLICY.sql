-- Add UPDATE policy to allow updating comment and like counts
-- Run this in Supabase SQL Editor

-- Create policy to allow updating comment and like counts
CREATE POLICY "Anyone can update counts"
ON public.videos
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Verify the policy was created
SELECT policyname, cmd, roles
FROM pg_policies
WHERE tablename = 'videos' AND cmd = 'UPDATE';

-- Now sync all comment counts
UPDATE public.videos v
SET comments = (
    SELECT COUNT(*)
    FROM public.video_comments vc
    WHERE vc.video_id = v.id
);

-- Verify the counts are synced
SELECT 
    v.id,
    v.comments as stored_count,
    COUNT(vc.id) as actual_count,
    CASE 
        WHEN v.comments = COUNT(vc.id) THEN '✅ SYNCED'
        ELSE '❌ MISMATCH'
    END as status
FROM public.videos v
LEFT JOIN public.video_comments vc ON vc.video_id = v.id
GROUP BY v.id
ORDER BY actual_count DESC;

-- Success message
SELECT '✅ UPDATE policy created and counts synced!' as result;
