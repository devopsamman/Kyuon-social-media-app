-- SQL script to create video_likes table for reels/videos
-- This tracks which users liked which videos
-- Run this in your Supabase SQL Editor

-- Create video_likes table
CREATE TABLE IF NOT EXISTS public.video_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    -- Ensure one user can only like a video once
    UNIQUE(video_id, user_id)
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_video_likes_video_id ON public.video_likes(video_id);
CREATE INDEX IF NOT EXISTS idx_video_likes_user_id ON public.video_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_video_likes_video_user ON public.video_likes(video_id, user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE public.video_likes ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Video likes are viewable by everyone" ON public.video_likes;
DROP POLICY IF EXISTS "Users can insert their own video likes" ON public.video_likes;
DROP POLICY IF EXISTS "Users can delete their own video likes" ON public.video_likes;

-- RLS Policies
-- Allow anyone to read video likes
CREATE POLICY "Video likes are viewable by everyone" 
    ON public.video_likes FOR SELECT 
    USING (true);

-- Allow authenticated users to insert their own likes
CREATE POLICY "Users can insert their own video likes" 
    ON public.video_likes FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own likes (for unlike functionality)
CREATE POLICY "Users can delete their own video likes" 
    ON public.video_likes FOR DELETE 
    USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON public.video_likes TO authenticated;
GRANT SELECT ON public.video_likes TO anon;

-- Function to get like count for a video
CREATE OR REPLACE FUNCTION get_video_like_count(video_uuid UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM public.video_likes WHERE video_id = video_uuid);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user liked a video
CREATE OR REPLACE FUNCTION user_liked_video(video_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS(SELECT 1 FROM public.video_likes WHERE video_id = video_uuid AND user_id = user_uuid);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
