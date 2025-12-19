-- SQL script to create post_likes table for posts
-- This tracks which users liked which posts
-- Run this in your Supabase SQL Editor

-- Create post_likes table
CREATE TABLE IF NOT EXISTS public.post_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    -- Ensure one user can only like a post once
    UNIQUE(post_id, user_id)
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON public.post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON public.post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_post_user ON public.post_likes(post_id, user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Post likes are viewable by everyone" ON public.post_likes;
DROP POLICY IF EXISTS "Users can insert their own post likes" ON public.post_likes;
DROP POLICY IF EXISTS "Users can delete their own post likes" ON public.post_likes;

-- RLS Policies
-- Allow anyone to read post likes
CREATE POLICY "Post likes are viewable by everyone" 
    ON public.post_likes FOR SELECT 
    USING (true);

-- Allow authenticated users to insert their own likes
CREATE POLICY "Users can insert their own post likes" 
    ON public.post_likes FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own likes (for unlike functionality)
CREATE POLICY "Users can delete their own post likes" 
    ON public.post_likes FOR DELETE 
    USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON public.post_likes TO authenticated;
GRANT SELECT ON public.post_likes TO anon;
