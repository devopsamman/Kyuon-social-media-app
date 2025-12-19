-- SQL script to create video_comments table for reels/videos
-- Run this in your Supabase SQL Editor

-- Create video_comments table
CREATE TABLE IF NOT EXISTS public.video_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_video_comments_video_id ON public.video_comments(video_id);
CREATE INDEX IF NOT EXISTS idx_video_comments_user_id ON public.video_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_video_comments_created_at ON public.video_comments(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.video_comments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Video comments are viewable by everyone" ON public.video_comments;
DROP POLICY IF EXISTS "Users can insert their own video comments" ON public.video_comments;
DROP POLICY IF EXISTS "Users can update their own video comments" ON public.video_comments;
DROP POLICY IF EXISTS "Users can delete their own video comments" ON public.video_comments;

-- RLS Policies
-- Allow anyone to read video comments
CREATE POLICY "Video comments are viewable by everyone" 
    ON public.video_comments FOR SELECT 
    USING (true);

-- Allow authenticated users to insert their own comments
CREATE POLICY "Users can insert their own video comments" 
    ON public.video_comments FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own comments
CREATE POLICY "Users can update their own video comments" 
    ON public.video_comments FOR UPDATE 
    USING (auth.uid() = user_id);

-- Allow users to delete their own comments
CREATE POLICY "Users can delete their own video comments" 
    ON public.video_comments FOR DELETE 
    USING (auth.uid() = user_id);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_video_comments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_video_comments_updated_at ON public.video_comments;

CREATE TRIGGER update_video_comments_updated_at
    BEFORE UPDATE ON public.video_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_video_comments_updated_at();

-- Grant permissions
GRANT ALL ON public.video_comments TO authenticated;
GRANT SELECT ON public.video_comments TO anon;
