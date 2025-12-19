-- Fix the specific video and test if updates work
-- Run this in Supabase SQL Editor

-- Step 1: Sync the current count
UPDATE public.videos
SET comments = 2
WHERE id = '260cb041-1c9f-4876-b82d-1fa82d817741';

-- Step 2: Verify it updated
SELECT id, comments as updated_count
FROM public.videos
WHERE id = '260cb041-1c9f-4876-b82d-1fa92d817741';

-- Step 3: Test incrementing it manually
UPDATE public.videos
SET comments = comments + 1
WHERE id = '260cb041-1c9f-4876-b82d-1fa92d817741';

-- Step 4: Check if the increment worked
SELECT id, comments as after_increment
FROM public.videos
WHERE id = '260cb041-1c9f-4876-b82d-1fa92d817741';

-- Step 5: Check for any restrictive Row Level Security policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'videos';

-- If RLS is preventing updates, we need to add a policy
-- Tell me what the above query returns
