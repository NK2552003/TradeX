-- 020_universal_link_graph.sql
--
-- Universal Bidirectional Link Graph:
-- Connects all 8 domain entity types seamlessly across TradeX:
--   1. Note (Writing-Desk trader note)
--   2. Journal (Trade execution record)
--   3. Strategy (Quantitative trading playbook)
--   4. AiCopilot (AI chat thread or trade setup)
--   5. CommunityPost (Social analysis or signal post)
--   6. MessageThread (Direct message or desk chat thread)
--   7. Ticker (Market symbol)
--   8. Trader (Peer profile)
--
-- Mirrors models in lib/core/app-ui/models/app_models.dart (AppLinkRef, AppLinkKind)
-- and lib/core/linking/link_graph.dart.

CREATE TABLE IF NOT EXISTS universal_link_edges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    source_kind TEXT NOT NULL
        CHECK (source_kind IN ('note', 'journal', 'strategy', 'aiCopilot', 'communityPost', 'messageThread', 'ticker', 'trader')),
    source_id TEXT NOT NULL,
    target_kind TEXT NOT NULL
        CHECK (target_kind IN ('note', 'journal', 'strategy', 'aiCopilot', 'communityPost', 'messageThread', 'ticker', 'trader')),
    target_id TEXT NOT NULL,
    label TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, source_kind, source_id, target_kind, target_id)
);

-- Fast lookup indexes
CREATE INDEX IF NOT EXISTS idx_universal_links_source 
    ON universal_link_edges(user_id, source_kind, source_id);

CREATE INDEX IF NOT EXISTS idx_universal_links_target 
    ON universal_link_edges(user_id, target_kind, target_id);

-- Enable Row Level Security (RLS)
ALTER TABLE universal_link_edges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own universal links"
    ON universal_link_edges FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Stored Function: Idempotent Symmetric Bidirectional Link Creation
CREATE OR REPLACE FUNCTION create_universal_link(
    p_src_kind TEXT,
    p_src_id TEXT,
    p_tgt_kind TEXT,
    p_tgt_id TEXT,
    p_label TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Avoid self-linking
    IF p_src_kind = p_tgt_kind AND p_src_id = p_tgt_id THEN
        RETURN;
    END IF;

    -- Forward edge
    INSERT INTO universal_link_edges (user_id, source_kind, source_id, target_kind, target_id, label, metadata)
    VALUES (v_user, p_src_kind, p_src_id, p_tgt_kind, p_tgt_id, p_label, p_metadata)
    ON CONFLICT (user_id, source_kind, source_id, target_kind, target_id) DO NOTHING;

    -- Backward symmetric edge
    INSERT INTO universal_link_edges (user_id, source_kind, source_id, target_kind, target_id, label, metadata)
    VALUES (v_user, p_tgt_kind, p_tgt_id, p_src_kind, p_src_id, p_label, p_metadata)
    ON CONFLICT (user_id, source_kind, source_id, target_kind, target_id) DO NOTHING;
END;
$$;

-- Stored Function: Symmetric Bidirectional Unlink
CREATE OR REPLACE FUNCTION delete_universal_link(
    p_src_kind TEXT,
    p_src_id TEXT,
    p_tgt_kind TEXT,
    p_tgt_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    DELETE FROM universal_link_edges
    WHERE user_id = v_user
      AND ((source_kind = p_src_kind AND source_id = p_src_id AND target_kind = p_tgt_kind AND target_id = p_tgt_id)
        OR (source_kind = p_tgt_kind AND source_id = p_tgt_id AND target_kind = p_src_kind AND target_id = p_src_id));
END;
$$;

-- Stored Function: Query Connected Links for an Entity
CREATE OR REPLACE FUNCTION get_universal_links(
    p_kind TEXT,
    p_id TEXT
)
RETURNS TABLE (
    id UUID,
    target_kind TEXT,
    target_id TEXT,
    label TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
    SELECT 
        id,
        target_kind,
        target_id,
        label,
        metadata,
        created_at
    FROM universal_link_edges
    WHERE user_id = auth.uid()
      AND source_kind = p_kind
      AND source_id = p_id
    ORDER BY created_at DESC;
$$;
