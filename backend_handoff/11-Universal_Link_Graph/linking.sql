-- linking.sql (Universal Link Graph)
-- Core stored procedures and triggers for universal bidirectional linking.

-- 1. Create a bidirectional link between any two records
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

    -- Prevent self links
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

-- 2. Unlink bidirectional records
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
