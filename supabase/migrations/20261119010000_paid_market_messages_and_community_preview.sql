-- Enforce paid Market Intelligence and Messages at the database boundary while
-- exposing only a small, whitelisted market preview to authenticated Community
-- users. Service-role market synchronization continues to bypass RLS.

BEGIN;

CREATE OR REPLACE FUNCTION tradex_private.has_paid_tier(p_user uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p_user IS NOT NULL
    AND tradex_private.account_active(p_user)
    AND tradex_private.effective_tier(p_user) IN ('premium', 'enterprise');
$$;

REVOKE ALL ON FUNCTION tradex_private.has_paid_tier(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION tradex_private.has_paid_tier(uuid) TO authenticated, service_role;

-- Full market tables are paid-only. Anonymous and Free users use the bounded
-- Community RPC below instead of receiving direct table access.
ALTER TABLE public.market_universe ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_fundamentals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dividends ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analyst_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.holders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.options_expirations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.options_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news_article_tickers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.screener_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.screener_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.market_screener_snapshots ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  target_table text;
  existing_policy record;
BEGIN
  FOREACH target_table IN ARRAY ARRAY[
    'market_universe', 'tickers', 'stock_quotes', 'stock_fundamentals',
    'stock_price_history', 'stock_details', 'dividends', 'stock_splits',
    'analyst_recommendations', 'holders', 'options_expirations',
    'options_contracts', 'news_articles', 'news_article_tickers',
    'screener_categories', 'screener_results', 'market_screener_snapshots'
  ] LOOP
    FOR existing_policy IN
      SELECT policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = target_table
        AND cmd = 'SELECT'
    LOOP
      EXECUTE format(
        'DROP POLICY IF EXISTS %I ON public.%I',
        existing_policy.policyname,
        target_table
      );
    END LOOP;
    EXECUTE format(
      'CREATE POLICY paid_market_read ON public.%I FOR SELECT TO authenticated USING (tradex_private.has_paid_tier((SELECT auth.uid())))',
      target_table
    );
  END LOOP;
END $$;

REVOKE SELECT ON
  public.market_universe,
  public.tickers,
  public.stock_quotes,
  public.stock_fundamentals,
  public.stock_price_history,
  public.stock_details,
  public.dividends,
  public.stock_splits,
  public.analyst_recommendations,
  public.holders,
  public.options_expirations,
  public.options_contracts,
  public.news_articles,
  public.news_article_tickers,
  public.screener_categories,
  public.screener_results,
  public.market_screener_snapshots
FROM anon;

GRANT SELECT ON
  public.market_universe,
  public.tickers,
  public.stock_quotes,
  public.stock_fundamentals,
  public.stock_price_history,
  public.stock_details,
  public.dividends,
  public.stock_splits,
  public.analyst_recommendations,
  public.holders,
  public.options_expirations,
  public.options_contracts,
  public.news_articles,
  public.news_article_tickers,
  public.screener_categories,
  public.screener_results,
  public.market_screener_snapshots
TO authenticated;

CREATE OR REPLACE FUNCTION public.community_market_preview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  caller uuid := auth.uid();
  allowed_symbols constant text[] := ARRAY[
    'AAPL', 'MSFT', 'NVDA', 'SPY', 'QQQ', 'BTC-USD', 'ETH-USD', '^GSPC'
  ];
BEGIN
  IF caller IS NULL OR NOT tradex_private.account_active(caller) THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'quotes', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data) ORDER BY row_data.sort_order)
      FROM (
        SELECT
          q.ticker,
          COALESCE(t.name, q.ticker) AS name,
          COALESCE(t.market, 'US') AS market,
          COALESCE(t.currency, 'USD') AS currency,
          q.price,
          q.previous_close,
          q.day_high,
          q.day_low,
          q.volume,
          q.change_pct,
          q.updated_at,
          array_position(allowed_symbols, q.ticker) AS sort_order
        FROM public.stock_quotes q
        JOIN public.tickers t ON t.ticker = q.ticker
        WHERE q.ticker = ANY(allowed_symbols)
        ORDER BY array_position(allowed_symbols, q.ticker)
        LIMIT 8
      ) row_data
    ), '[]'::jsonb),
    'news', COALESCE((
      SELECT jsonb_agg(to_jsonb(news_row) ORDER BY news_row.published_at DESC)
      FROM (
        SELECT
          n.id,
          n.title,
          n.summary,
          n.link,
          n.publisher,
          n.thumbnail_url,
          n.content_type,
          n.published_at,
          COALESCE((
            SELECT jsonb_agg(link.ticker ORDER BY link.ticker)
            FROM public.news_article_tickers link
            WHERE link.article_id = n.id
              AND link.ticker = ANY(allowed_symbols)
          ), '[]'::jsonb) AS related_tickers
        FROM public.news_articles n
        WHERE EXISTS (
          SELECT 1
          FROM public.news_article_tickers link
          WHERE link.article_id = n.id
            AND link.ticker = ANY(allowed_symbols)
        )
        ORDER BY n.published_at DESC NULLS LAST
        LIMIT 6
      ) news_row
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.community_market_preview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.community_market_preview() TO authenticated;

-- One bounded payload replaces dozens of table/count queries on the paid
-- overview. Aggregation stays inside Postgres and only visible rows leave it.
CREATE OR REPLACE FUNCTION public.market_overview_payload()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  caller uuid := auth.uid();
  reference_symbols constant text[] := ARRAY[
    '^IXIC','^GSPTSE','^GSPC','^DJI','^RUT','^VIX','^BVSP',
    '^GDAXI','^FCHI','^STOXX50E','^FTSE','^N100','^BSESN','^HSI',
    '000001.SS','^AXJO','^N225','^KS11','GC=F','SI=F','CL=F','NG=F',
    'HG=F','EURUSD=X','GBPUSD=X','USDJPY=X','USDINR=X','BTC-USD',
    'ETH-USD','^TNX','^TYX','^FVX','^IRX','DX-Y.NYB'
  ];
BEGIN
  IF caller IS NULL OR NOT tradex_private.has_paid_tier(caller) THEN
    RAISE EXCEPTION 'AlphaJournal Basic or Pro is required'
      USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'quotes', COALESCE((
      WITH candidates AS (
        (SELECT ticker FROM public.stock_quotes ORDER BY change_pct DESC NULLS LAST LIMIT 20)
        UNION
        (SELECT ticker FROM public.stock_quotes ORDER BY change_pct ASC NULLS LAST LIMIT 20)
        UNION
        (SELECT ticker FROM public.stock_quotes ORDER BY volume DESC NULLS LAST LIMIT 20)
        UNION
        (SELECT ticker FROM public.stock_quotes WHERE ticker = ANY(reference_symbols))
      )
      SELECT jsonb_agg(to_jsonb(quote_row) ORDER BY quote_row.ticker)
      FROM (
        SELECT
          q.ticker,
          COALESCE(t.name, q.ticker) AS name,
          COALESCE(t.market, 'US') AS market,
          t.exchange,
          COALESCE(t.currency, 'USD') AS currency,
          t.asset_type,
          q.price,
          q.previous_close,
          q.day_high,
          q.day_low,
          q.volume,
          q.change_pct,
          q.updated_at,
          f.market_cap,
          f.pe_ratio,
          f.sector,
          f.industry,
          f.dividend_yield,
          f.beta,
          f.fifty_two_week_high,
          f.fifty_two_week_low
        FROM candidates c
        JOIN public.stock_quotes q ON q.ticker = c.ticker
        LEFT JOIN public.tickers t ON t.ticker = q.ticker
        LEFT JOIN public.stock_fundamentals f ON f.ticker = q.ticker
      ) quote_row
    ), '[]'::jsonb),
    'screeners', jsonb_build_object(
      'top_gainers', COALESCE((
        SELECT jsonb_agg(to_jsonb(gainer) ORDER BY gainer.change_pct DESC)
        FROM (
          SELECT q.ticker, COALESCE(t.name, q.ticker) AS name, q.price,
                 q.change_pct, q.volume, COALESCE(t.currency, 'USD') AS currency
          FROM public.stock_quotes q
          LEFT JOIN public.tickers t ON t.ticker = q.ticker
          WHERE q.change_pct >= 0
          ORDER BY q.change_pct DESC NULLS LAST
          LIMIT 20
        ) gainer
      ), '[]'::jsonb),
      'top_losers', COALESCE((
        SELECT jsonb_agg(to_jsonb(loser) ORDER BY loser.change_pct ASC)
        FROM (
          SELECT q.ticker, COALESCE(t.name, q.ticker) AS name, q.price,
                 q.change_pct, q.volume, COALESCE(t.currency, 'USD') AS currency
          FROM public.stock_quotes q
          LEFT JOIN public.tickers t ON t.ticker = q.ticker
          WHERE q.change_pct < 0
          ORDER BY q.change_pct ASC NULLS LAST
          LIMIT 20
        ) loser
      ), '[]'::jsonb),
      'most_active', COALESCE((
        SELECT jsonb_agg(to_jsonb(active_row) ORDER BY active_row.volume DESC)
        FROM (
          SELECT q.ticker, COALESCE(t.name, q.ticker) AS name, q.price,
                 q.change_pct, q.volume, COALESCE(t.currency, 'USD') AS currency
          FROM public.stock_quotes q
          LEFT JOIN public.tickers t ON t.ticker = q.ticker
          ORDER BY q.volume DESC NULLS LAST
          LIMIT 20
        ) active_row
      ), '[]'::jsonb)
    ),
    'news', COALESCE((
      SELECT jsonb_agg(to_jsonb(news_row) ORDER BY news_row.published_at DESC)
      FROM (
        SELECT
          n.id,
          n.title,
          n.summary,
          n.link,
          n.publisher,
          n.thumbnail_url,
          n.content_type,
          n.published_at,
          COALESCE((
            SELECT jsonb_agg(link.ticker ORDER BY link.ticker)
            FROM public.news_article_tickers link
            WHERE link.article_id = n.id
          ), '[]'::jsonb) AS related_tickers
        FROM public.news_articles n
        ORDER BY n.published_at DESC NULLS LAST
        LIMIT 25
      ) news_row
    ), '[]'::jsonb),
    'manifest', jsonb_build_object(
      'generated_at', now(),
      'data_source', 'supabase_live',
      'universe_count', (SELECT count(*) FROM public.market_universe),
      'quote_count', (SELECT count(*) FROM public.stock_quotes),
      'detail_count', (SELECT count(*) FROM public.stock_details),
      'history_count', (SELECT count(DISTINCT ticker) FROM public.stock_price_history),
      'news_count', (SELECT count(*) FROM public.news_articles),
      'sector_counts', COALESCE((
        SELECT jsonb_object_agg(sector_rows.sector, sector_rows.total)
        FROM (
          SELECT sector, count(*) AS total
          FROM public.stock_fundamentals
          WHERE sector IS NOT NULL AND sector <> ''
          GROUP BY sector
        ) sector_rows
      ), '{}'::jsonb),
      'change_distribution', (
        SELECT jsonb_build_object(
          'total', count(*),
          'gainers_count', count(*) FILTER (WHERE change_pct > 0),
          'losers_count', count(*) FILTER (WHERE change_pct < 0),
          'best_gain', COALESCE(max(change_pct), 0),
          'worst_loss', COALESCE(min(change_pct), 0),
          'bins', jsonb_build_object(
            '< -5%', count(*) FILTER (WHERE change_pct < -5),
            '-5 to -2%', count(*) FILTER (WHERE change_pct >= -5 AND change_pct < -2),
            '-2 to 0%', count(*) FILTER (WHERE change_pct >= -2 AND change_pct < 0),
            '0 to 2%', count(*) FILTER (WHERE change_pct >= 0 AND change_pct < 2),
            '2 to 5%', count(*) FILTER (WHERE change_pct >= 2 AND change_pct < 5),
            '> 5%', count(*) FILTER (WHERE change_pct >= 5)
          )
        )
        FROM public.stock_quotes
      )
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.market_overview_payload() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.market_overview_payload() TO authenticated;

-- Make every participant-based Messages policy inherit the paid-tier check.
CREATE OR REPLACE FUNCTION tradex_private.chat_member(p_thread uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT tradex_private.has_paid_tier(auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.chat_participants
      WHERE thread_id = p_thread AND user_id = auth.uid()
    );
$$;

CREATE OR REPLACE FUNCTION tradex_private.chat_owner(p_thread uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT tradex_private.has_paid_tier(auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.chat_threads
      WHERE id = p_thread AND created_by = auth.uid()
    );
$$;

DO $$
DECLARE
  existing_policy record;
BEGIN
  FOR existing_policy IN
    SELECT tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('chat_threads', 'chat_participants', 'chat_messages')
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON public.%I',
      existing_policy.policyname,
      existing_policy.tablename
    );
  END LOOP;
END $$;

CREATE POLICY chat_read ON public.chat_threads FOR SELECT TO authenticated
  USING (tradex_private.chat_member(id) OR tradex_private.chat_owner(id));
CREATE POLICY chat_create ON public.chat_threads FOR INSERT TO authenticated
  WITH CHECK (
    created_by = (SELECT auth.uid())
    AND tradex_private.has_paid_tier((SELECT auth.uid()))
    AND (SELECT tradex_private.feature_enabled('messages'))
  );
CREATE POLICY chat_update ON public.chat_threads FOR UPDATE TO authenticated
  USING (tradex_private.chat_member(id) OR tradex_private.chat_owner(id))
  WITH CHECK (tradex_private.chat_member(id) OR tradex_private.chat_owner(id));

CREATE POLICY participants_read ON public.chat_participants FOR SELECT TO authenticated
  USING (tradex_private.chat_member(thread_id) OR tradex_private.chat_owner(thread_id));
CREATE POLICY participants_insert ON public.chat_participants FOR INSERT TO authenticated
  WITH CHECK (
    tradex_private.chat_owner(thread_id)
    AND tradex_private.has_paid_tier((SELECT auth.uid()))
    AND (SELECT tradex_private.feature_enabled('messages'))
  );
CREATE POLICY participants_update ON public.chat_participants FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()) AND tradex_private.chat_member(thread_id))
  WITH CHECK (user_id = (SELECT auth.uid()) AND tradex_private.chat_member(thread_id));
CREATE POLICY participants_delete ON public.chat_participants FOR DELETE TO authenticated
  USING (
    (user_id = (SELECT auth.uid()) AND tradex_private.chat_member(thread_id))
    OR tradex_private.chat_owner(thread_id)
  );

CREATE POLICY messages_read ON public.chat_messages FOR SELECT TO authenticated
  USING (tradex_private.chat_member(thread_id) AND NOT admin_hidden);
CREATE POLICY messages_insert ON public.chat_messages FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = (SELECT auth.uid())
    AND tradex_private.chat_member(thread_id)
    AND tradex_private.has_paid_tier((SELECT auth.uid()))
    AND (SELECT tradex_private.feature_enabled('messages'))
    AND NOT admin_hidden
  );
CREATE POLICY messages_update ON public.chat_messages FOR UPDATE TO authenticated
  USING (
    sender_id = (SELECT auth.uid())
    AND tradex_private.chat_member(thread_id)
    AND NOT admin_hidden
  )
  WITH CHECK (
    sender_id = (SELECT auth.uid())
    AND tradex_private.chat_member(thread_id)
    AND NOT admin_hidden
  );
CREATE POLICY messages_delete ON public.chat_messages FOR DELETE TO authenticated
  USING (
    sender_id = (SELECT auth.uid())
    AND tradex_private.chat_member(thread_id)
    AND NOT admin_hidden
  );

NOTIFY pgrst, 'reload schema';

COMMIT;
