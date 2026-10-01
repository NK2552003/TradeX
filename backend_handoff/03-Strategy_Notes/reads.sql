-- 012_linked_notes_reads.sql
--
-- Derived reads and the public boundary. Nothing here stores anything.
--
--   strategy_performance          owner-facing, RLS-respecting, derived per read
--   public_document(kind, id)     the ONLY entry point for an unauthenticated
--                                 reader, and the only column allow-list there is
--
-- See docs_/LINKED_NOTES_BACKEND_HANDOFF.md sections 6 and 9.

BEGIN;

-- `security_invoker = true` is load-bearing. Without it the view runs with its
-- owner's rights and bypasses RLS, which would let any authenticated user read
-- every other trader's playbook performance. The view must see what the caller
-- sees and nothing more.
CREATE OR REPLACE VIEW strategy_performance WITH (security_invoker = true) AS
WITH closed AS (
  SELECT strategy_id, user_id, pnl, r_multiple,
         COALESCE(closed_at, opened_at) AS at
    FROM journal_entries
   WHERE strategy_id IS NOT NULL
     AND outcome IS DISTINCT FROM 'open'
)
SELECT
  s.id                                                     AS strategy_id,
  s.user_id,
  COUNT(c.*)                                               AS trades,
  COALESCE(SUM(c.pnl), 0)                                  AS net_pnl,
  CASE WHEN COUNT(c.*) = 0 THEN 0
       ELSE ROUND(100.0 * COUNT(c.*) FILTER (WHERE c.pnl > 0) / COUNT(c.*), 2)
  END                                                      AS win_rate,
  COALESCE(AVG(c.r_multiple), 0)                           AS avg_r
FROM strategies s
LEFT JOIN closed c ON c.strategy_id = s.id
GROUP BY s.id, s.user_id;

-- win_rate is 0..100 here, matching AppStrategy.winRate. AppJournalStats.winRate
-- and the two stat-row models are 0..1. Do not convert between them anywhere.

GRANT SELECT ON strategy_performance TO authenticated;

-- ---------------------------------------------------------------------------
-- Public read path. A visitor has no workspace, so a visitor cannot build the
-- link graph the app builds client-side: for an anonymous caller watchAll()
-- would return every public record in the product. One record, refs already
-- resolved, is a different read — not the same read with fewer rows.
-- ---------------------------------------------------------------------------

-- Aggregates over rows the caller cannot select. SECURITY DEFINER by necessity;
-- the `< 5` floor is why it is not a leak: a playbook with one closed trade
-- behind it would not report a statistic, it would report that trade's outcome.
CREATE OR REPLACE FUNCTION public_strategy_performance(p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN COUNT(*) < 5 THEN NULL ELSE jsonb_build_object(
           'total_trades', COUNT(*),
           'win_rate',     ROUND(100.0 * COUNT(*) FILTER (WHERE c.pnl > 0)
                                 / NULLIF(COUNT(*), 0), 2),
           'avg_r',        ROUND(AVG(c.r_multiple)::numeric, 2),
           'net_pnl',      ROUND(SUM(c.pnl)::numeric, 2)
         ) END
    FROM journal_entries c
   WHERE c.strategy_id = p_id
     AND c.outcome IS DISTINCT FROM 'open';
$$;

-- Which refs survive the strip. Journal entries never do — the share contract
-- publishes a playbook's figures, not the trades behind them. Both arms
-- re-check the publish flag on BOTH ends: this is reachable by anon, so its
-- arguments are hostile input.
CREATE OR REPLACE FUNCTION public_refs(p_kind text, p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(jsonb_agg(r ORDER BY r ->> 'title'), '[]'::jsonb)
  FROM (
    -- public notes filed under a public strategy
    SELECT jsonb_build_object(
             'kind', 'note', 'id', n.id,
             'title', n.title, 'subtitle', n.note_type
           ) AS r
      FROM trader_notes n
      JOIN strategies s ON s.id = n.strategy_id
     WHERE p_kind = 'strategy'
       AND s.id = p_id AND s.visibility = 'public'
       AND n.is_public
    UNION ALL
    -- the public playbook a public note is filed under
    SELECT jsonb_build_object(
             'kind', 'strategy', 'id', s.id,
             'title', s.title, 'subtitle', s.summary
           )
      FROM trader_notes n
      JOIN strategies s ON s.id = n.strategy_id
     WHERE p_kind = 'note'
       AND n.id = p_id AND n.is_public
       AND s.visibility = 'public'
  ) refs;
$$;

-- A SECURITY DEFINER function bypasses RLS. That is the point, and it is also
-- why the column list below IS the security boundary: there is no second check
-- behind it. Deliberately absent: both mirror arrays, the raw user_id (handle is
-- the public identity), version_count, and every owner-scoped flag.
--
-- A missing record and a private record return the same thing: no row, hence
-- NULL. Do not raise not-found for one and forbidden for the other — that
-- difference is an oracle a script can walk to enumerate which ids exist.
CREATE OR REPLACE FUNCTION public_document(p_kind text, p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
           'kind', 'strategy', 'id', s.id, 'name', s.title,
           'summary', s.summary, 'body', s.content, 'status', s.status,
           'tags', s.tags, 'tickers', s.linked_tickers,
           'updated_at', s.updated_at,
           'author', jsonb_build_object('handle', p.handle,
                                        'display_name', p.display_name,
                                        'avatar_url', p.avatar_url),
           'performance', public_strategy_performance(s.id),
           'refs', public_refs('strategy', s.id)
         )
    FROM strategies s JOIN profiles p ON p.id = s.user_id
   WHERE p_kind = 'strategy' AND s.id = p_id AND s.visibility = 'public'
  UNION ALL
  SELECT jsonb_build_object(
           'kind', 'note', 'id', n.id, 'title', n.title,
           'body', n.content, 'note_type', n.note_type,
           'tags', n.tags, 'tickers', n.linked_tickers,
           'updated_at', n.updated_at,
           'like_count', n.like_count, 'view_count', n.view_count,
           'author', jsonb_build_object('handle', p.handle,
                                        'display_name', p.display_name,
                                        'avatar_url', p.avatar_url),
           'refs', public_refs('note', n.id)
         )
    FROM trader_notes n JOIN profiles p ON p.id = n.user_id
   WHERE p_kind = 'note' AND n.id = p_id AND n.is_public
   LIMIT 1;
$$;

-- One door. The two helpers are never granted: inside a SECURITY DEFINER
-- function the effective role is the owner, so the nested EXECUTE checks pass
-- against the owner and anon still cannot call them directly.
REVOKE EXECUTE ON FUNCTION public_document(text, uuid)        FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public_refs(text, uuid)            FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public_strategy_performance(uuid)  FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public_document(text, uuid)        TO anon, authenticated;

COMMIT;
