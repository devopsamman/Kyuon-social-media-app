-- ============================================
-- SEARCH FUNCTIONALITY DATABASE SETUP
-- ============================================

-- 1. Create indexes for faster search queries
CREATE INDEX IF NOT EXISTS idx_profiles_username_search ON profiles USING gin(to_tsvector('english', username));
CREATE INDEX IF NOT EXISTS idx_profiles_full_name_search ON profiles USING gin(to_tsvector('english', full_name));
CREATE INDEX IF NOT EXISTS idx_posts_content_search ON posts USING gin(to_tsvector('english', content));
CREATE INDEX IF NOT EXISTS idx_videos_title_search ON videos USING gin(to_tsvector('english', title));

-- Simple pattern matching indexes (fallback)
CREATE INDEX IF NOT EXISTS idx_profiles_username_pattern ON profiles (username text_pattern_ops);
CREATE INDEX IF NOT EXISTS idx_profiles_full_name_pattern ON profiles (full_name text_pattern_ops);

-- 2. Create search function for users
DROP FUNCTION IF EXISTS search_users(TEXT, INT);
CREATE OR REPLACE FUNCTION search_users(search_query TEXT, result_limit INT DEFAULT 20)
RETURNS TABLE (
  id UUID,
  username TEXT,
  full_name TEXT,
  profile_image_url TEXT,
  bio TEXT,
  followers_count INT,
  following_count INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.username,
    p.full_name,
    p.profile_image_url,
    p.bio,
    p.followers_count,
    p.following_count
  FROM profiles p
  WHERE 
    p.username ILIKE '%' || search_query || '%'
    OR p.full_name ILIKE '%' || search_query || '%'
  ORDER BY 
    CASE 
      WHEN p.username ILIKE search_query || '%' THEN 1
      WHEN p.full_name ILIKE search_query || '%' THEN 2
      ELSE 3
    END,
    p.followers_count DESC
  LIMIT result_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create search function for posts
DROP FUNCTION IF EXISTS search_posts(TEXT, INT);
CREATE OR REPLACE FUNCTION search_posts(search_query TEXT, result_limit INT DEFAULT 20)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  content TEXT,
  image_url TEXT,
  created_at TIMESTAMPTZ,
  username TEXT,
  profile_image_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.user_id,
    p.content,
    p.image_url,
    p.created_at,
    prof.username,
    prof.profile_image_url
  FROM posts p
  INNER JOIN profiles prof ON p.user_id = prof.id
  WHERE 
    p.content ILIKE '%' || search_query || '%'
    OR prof.username ILIKE '%' || search_query || '%'
  ORDER BY 
    p.created_at DESC
  LIMIT result_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create search function for reels
DROP FUNCTION IF EXISTS search_reels(TEXT, INT);
CREATE OR REPLACE FUNCTION search_reels(search_query TEXT, result_limit INT DEFAULT 20)
RETURNS TABLE (
  id UUID,
  uploader_id UUID,
  title TEXT,
  video_url TEXT,
  thumbnail_url TEXT,
  created_at TIMESTAMPTZ,
  username TEXT,
  profile_image_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id,
    v.uploader_id,
    v.title,
    v.video_url,
    v.thumbnail_url,
    v.created_at,
    prof.username,
    prof.profile_image_url
  FROM videos v
  INNER JOIN profiles prof ON v.uploader_id = prof.id
  WHERE 
    v.title ILIKE '%' || search_query || '%'
    OR prof.username ILIKE '%' || search_query || '%'
  ORDER BY 
    v.created_at DESC
  LIMIT result_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Create combined search function (searches all)
DROP FUNCTION IF EXISTS search_all(TEXT, INT, INT, INT);
CREATE OR REPLACE FUNCTION search_all(
  search_query TEXT,
  user_limit INT DEFAULT 5,
  post_limit INT DEFAULT 10,
  reel_limit INT DEFAULT 10
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'users', (SELECT json_agg(u) FROM (SELECT * FROM search_users(search_query, user_limit)) u),
    'posts', (SELECT json_agg(p) FROM (SELECT * FROM search_posts(search_query, post_limit)) p),
    'reels', (SELECT json_agg(r) FROM (SELECT * FROM search_reels(search_query, reel_limit)) r)
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Grant execute permissions
GRANT EXECUTE ON FUNCTION search_users TO authenticated;
GRANT EXECUTE ON FUNCTION search_posts TO authenticated;
GRANT EXECUTE ON FUNCTION search_reels TO authenticated;
GRANT EXECUTE ON FUNCTION search_all TO authenticated;

-- 7. Create search history table (optional - for recent searches)
CREATE TABLE IF NOT EXISTS search_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  search_query TEXT NOT NULL,
  search_type TEXT DEFAULT 'all', -- 'all', 'users', 'posts', 'reels'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_search_history_user ON search_history(user_id, created_at DESC);

-- RLS for search history
ALTER TABLE search_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own search history" ON search_history;
DROP POLICY IF EXISTS "Users can insert own search history" ON search_history;
DROP POLICY IF EXISTS "Users can delete own search history" ON search_history;

-- Create policies
CREATE POLICY "Users can view own search history"
  ON search_history FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own search history"
  ON search_history FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own search history"
  ON search_history FOR DELETE
  USING (auth.uid() = user_id);

GRANT SELECT, INSERT, DELETE ON search_history TO authenticated;

-- Done!
SELECT 'Search functionality setup complete!' as status;
