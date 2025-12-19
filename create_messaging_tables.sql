-- ============================================
-- MESSAGING SYSTEM DATABASE SCHEMA
-- ============================================

-- 1. Create conversations table
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Participants (always 2 users for direct messages)
    user1_id UUID NOT NULL,
    user2_id UUID NOT NULL,
    
    -- Last message info for quick display
    last_message TEXT,
    last_message_at TIMESTAMP WITH TIME ZONE,
    last_message_sender_id UUID,
    
    -- Unread counts for each user
    user1_unread_count INTEGER DEFAULT 0,
    user2_unread_count INTEGER DEFAULT 0,
    
    -- Constraints
    CONSTRAINT conversations_user1_id_fkey FOREIGN KEY (user1_id) 
        REFERENCES public.profiles(id) ON DELETE CASCADE,
    CONSTRAINT conversations_user2_id_fkey FOREIGN KEY (user2_id) 
        REFERENCES public.profiles(id) ON DELETE CASCADE,
    CONSTRAINT conversations_different_users CHECK (user1_id != user2_id),
    -- Ensure unique conversation (user1_id should always be less than user2_id)
    CONSTRAINT conversations_unique_pair UNIQUE (user1_id, user2_id),
    CHECK (user1_id < user2_id)
);

-- 2. Create messages table
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    receiver_id UUID NOT NULL,
    
    message_text TEXT NOT NULL,
    message_type TEXT DEFAULT 'text', -- 'text', 'image', 'video', 'audio'
    media_url TEXT,
    
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) 
        REFERENCES public.conversations(id) ON DELETE CASCADE,
    CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) 
        REFERENCES public.profiles(id) ON DELETE CASCADE,
    CONSTRAINT messages_receiver_id_fkey FOREIGN KEY (receiver_id) 
        REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- 3. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_conversations_user1_id ON public.conversations(user1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_user2_id ON public.conversations(user2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON public.conversations(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON public.messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_is_read ON public.messages(is_read);

-- 4. Enable Row Level Security
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for conversations
-- Users can view conversations they're part of
CREATE POLICY "Users can view their conversations"
    ON public.conversations FOR SELECT
    USING (
        auth.uid() = user1_id OR 
        auth.uid() = user2_id
    );

-- Users can create conversations
CREATE POLICY "Users can create conversations"
    ON public.conversations FOR INSERT
    WITH CHECK (
        auth.uid() = user1_id OR 
        auth.uid() = user2_id
    );

-- Users can update their conversations
CREATE POLICY "Users can update their conversations"
    ON public.conversations FOR UPDATE
    USING (
        auth.uid() = user1_id OR 
        auth.uid() = user2_id
    );

-- 6. RLS Policies for messages
-- Users can view messages in their conversations
CREATE POLICY "Users can view their messages"
    ON public.messages FOR SELECT
    USING (
        auth.uid() = sender_id OR 
        auth.uid() = receiver_id
    );

-- Users can send messages
CREATE POLICY "Users can send messages"
    ON public.messages FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

-- Users can update their own messages (for read receipts)
CREATE POLICY "Users can update messages"
    ON public.messages FOR UPDATE
    USING (
        auth.uid() = sender_id OR 
        auth.uid() = receiver_id
    );

-- 7. Function to update conversation when new message is sent
CREATE OR REPLACE FUNCTION update_conversation_on_message()
RETURNS TRIGGER AS $$
BEGIN
    -- Update conversation's last message info
    UPDATE public.conversations
    SET 
        last_message = NEW.message_text,
        last_message_at = NEW.created_at,
        last_message_sender_id = NEW.sender_id,
        updated_at = NEW.created_at,
        -- Increment unread count for receiver
        user1_unread_count = CASE 
            WHEN user1_id = NEW.receiver_id THEN user1_unread_count + 1
            ELSE user1_unread_count
        END,
        user2_unread_count = CASE 
            WHEN user2_id = NEW.receiver_id THEN user2_unread_count + 1
            ELSE user2_unread_count
        END
    WHERE id = NEW.conversation_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Trigger to update conversation on new message
DROP TRIGGER IF EXISTS trigger_update_conversation_on_message ON public.messages;
CREATE TRIGGER trigger_update_conversation_on_message
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_on_message();

-- 9. Function to mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_as_read(
    p_conversation_id UUID,
    p_user_id UUID
)
RETURNS VOID AS $$
BEGIN
    -- Mark all unread messages from the other user as read
    UPDATE public.messages
    SET 
        is_read = TRUE,
        read_at = NOW()
    WHERE 
        conversation_id = p_conversation_id
        AND receiver_id = p_user_id
        AND is_read = FALSE;
    
    -- Reset unread count in conversation
    UPDATE public.conversations
    SET 
        user1_unread_count = CASE 
            WHEN user1_id = p_user_id THEN 0
            ELSE user1_unread_count
        END,
        user2_unread_count = CASE 
            WHEN user2_id = p_user_id THEN 0
            ELSE user2_unread_count
        END
    WHERE id = p_conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Function to get or create conversation between two users
CREATE OR REPLACE FUNCTION get_or_create_conversation(
    p_user1_id UUID,
    p_user2_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_conversation_id UUID;
    v_smaller_id UUID;
    v_larger_id UUID;
BEGIN
    -- Ensure user1_id < user2_id for consistency
    IF p_user1_id < p_user2_id THEN
        v_smaller_id := p_user1_id;
        v_larger_id := p_user2_id;
    ELSE
        v_smaller_id := p_user2_id;
        v_larger_id := p_user1_id;
    END IF;
    
    -- Try to find existing conversation
    SELECT id INTO v_conversation_id
    FROM public.conversations
    WHERE user1_id = v_smaller_id AND user2_id = v_larger_id;
    
    -- If not found, create new conversation
    IF v_conversation_id IS NULL THEN
        INSERT INTO public.conversations (user1_id, user2_id)
        VALUES (v_smaller_id, v_larger_id)
        RETURNING id INTO v_conversation_id;
    END IF;
    
    RETURN v_conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Grant permissions
GRANT SELECT, INSERT, UPDATE ON public.conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.messages TO authenticated;
GRANT EXECUTE ON FUNCTION get_or_create_conversation TO authenticated;
GRANT EXECUTE ON FUNCTION mark_messages_as_read TO authenticated;

-- 12. Enable real-time for messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;

-- Done!
SELECT 'Messaging system tables created successfully!' as status;
