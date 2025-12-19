-- Create followers table for follow/following relationships
CREATE TABLE IF NOT EXISTS public.followers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    follower_id UUID NOT NULL, -- The user who is following
    following_id UUID NOT NULL, -- The user being followed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT followers_follower_id_fkey FOREIGN KEY (follower_id) 
        REFERENCES public.profiles(id) ON DELETE CASCADE,
    CONSTRAINT followers_following_id_fkey FOREIGN KEY (following_id) 
        REFERENCES public.profiles(id) ON DELETE CASCADE,
    CONSTRAINT followers_unique_relationship UNIQUE (follower_id, following_id),
    CONSTRAINT followers_no_self_follow CHECK (follower_id != following_id)
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_followers_follower_id ON public.followers(follower_id);
CREATE INDEX IF NOT EXISTS idx_followers_following_id ON public.followers(following_id);
CREATE INDEX IF NOT EXISTS idx_followers_created_at ON public.followers(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.followers ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Allow users to read all follower relationships
CREATE POLICY "Anyone can view followers"
    ON public.followers FOR SELECT
    USING (true);

-- Allow users to follow others (insert)
CREATE POLICY "Users can follow others"
    ON public.followers FOR INSERT
    WITH CHECK (true);

-- Allow users to unfollow (delete their own follows)
CREATE POLICY "Users can unfollow"
    ON public.followers FOR DELETE
    USING (true);

-- Add follower/following counts to profiles table if they don't exist
DO $$ 
BEGIN
    -- Add followers_count column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'followers_count'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN followers_count INTEGER DEFAULT 0;
    END IF;
    
    -- Add following_count column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'following_count'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN following_count INTEGER DEFAULT 0;
    END IF;
END $$;

-- Function to update follower counts
CREATE OR REPLACE FUNCTION update_follower_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- Increment following_count for follower
        UPDATE public.profiles 
        SET following_count = following_count + 1 
        WHERE id = NEW.follower_id;
        
        -- Increment followers_count for the user being followed
        UPDATE public.profiles 
        SET followers_count = followers_count + 1 
        WHERE id = NEW.following_id;
        
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        -- Decrement following_count for follower
        UPDATE public.profiles 
        SET following_count = GREATEST(following_count - 1, 0) 
        WHERE id = OLD.follower_id;
        
        -- Decrement followers_count for the user being unfollowed
        UPDATE public.profiles 
        SET followers_count = GREATEST(followers_count - 1, 0) 
        WHERE id = OLD.following_id;
        
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically update counts
DROP TRIGGER IF EXISTS trigger_update_follower_counts ON public.followers;
CREATE TRIGGER trigger_update_follower_counts
    AFTER INSERT OR DELETE ON public.followers
    FOR EACH ROW
    EXECUTE FUNCTION update_follower_counts();

-- Recalculate existing follower/following counts
UPDATE public.profiles p
SET 
    followers_count = (
        SELECT COUNT(*) FROM public.followers f 
        WHERE f.following_id = p.id
    ),
    following_count = (
        SELECT COUNT(*) FROM public.followers f 
        WHERE f.follower_id = p.id
    );

-- Create helpful views
CREATE OR REPLACE VIEW public.user_followers AS
SELECT 
    f.id,
    f.follower_id,
    f.following_id,
    f.created_at,
    follower.username as follower_username,
    follower.profile_image_url as follower_avatar,
    following.username as following_username,
    following.profile_image_url as following_avatar
FROM public.followers f
LEFT JOIN public.profiles follower ON f.follower_id = follower.id
LEFT JOIN public.profiles following ON f.following_id = following.id;

-- Grant permissions
GRANT SELECT, INSERT, DELETE ON public.followers TO authenticated;
GRANT SELECT ON public.user_followers TO authenticated;

-- Verify the table was created
SELECT 
    'Followers table created successfully!' as status,
    COUNT(*) as follower_relationships
FROM public.followers;

SELECT 
    'Profiles updated with follower counts!' as status,
    COUNT(*) as profiles_with_counts
FROM public.profiles 
WHERE followers_count IS NOT NULL AND following_count IS NOT NULL;
