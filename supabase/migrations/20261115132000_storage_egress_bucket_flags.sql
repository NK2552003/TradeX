-- Ensure storage bucket visibility flags match Supabase Egress vs Cached Egress tiers:
-- - Public Smart CDN Cached Egress: avatars, community-attachments (`public = true`)
-- - Private RLS-protected Direct Egress: journal-attachments, note-attachments,
--   strategy-attachments, chat-attachments (`public = false`)

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'storage') THEN
    INSERT INTO storage.buckets (id, name, public)
    VALUES
      ('avatars', 'avatars', true),
      ('community-attachments', 'community-attachments', true),
      ('journal-attachments', 'journal-attachments', false),
      ('note-attachments', 'note-attachments', false),
      ('strategy-attachments', 'strategy-attachments', false),
      ('chat-attachments', 'chat-attachments', false)
    ON CONFLICT (id) DO UPDATE SET
      public = EXCLUDED.public;
  END IF;
END
$$;
