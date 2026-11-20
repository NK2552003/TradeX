-- Enrich the bounded Community market preview RPC so Free users see real
-- top gainers, top losers, 24-day closing-price sparklines, ticker details,
-- and deduplicated Market Wire news for ONLY the limited Community sidebar
-- preview set, while keeping full Market Intelligence tables paid-only.

BEGIN;

CREATE OR REPLACE FUNCTION public.community_market_preview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  caller uuid := auth.uid();
  core_symbols constant text[] := ARRAY[
    'AAPL', 'MSFT', 'NVDA', 'SPY', 'QQQ', 'BTC-USD', 'ETH-USD', '^GSPC'
  ];
BEGIN
  IF caller IS NULL OR NOT tradex_private.account_active(caller) THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  RETURN (
    WITH top_gainers_cte AS (
      SELECT q.ticker, q.change_pct
      FROM public.stock_quotes q
      JOIN public.tickers t ON t.ticker = q.ticker
      WHERE q.price IS NOT NULL
        AND q.price > 0
        AND q.change_pct IS NOT NULL
        AND q.change_pct > 0
      ORDER BY q.change_pct DESC NULLS LAST
      LIMIT 5
    ),
    top_losers_cte AS (
      SELECT q.ticker, q.change_pct
      FROM public.stock_quotes q
      JOIN public.tickers t ON t.ticker = q.ticker
      WHERE q.price IS NOT NULL
        AND q.price > 0
        AND q.change_pct IS NOT NULL
        AND q.change_pct < 0
      ORDER BY q.change_pct ASC NULLS LAST
      LIMIT 5
    ),
    dedup_news AS (
      SELECT DISTINCT ON (lower(trim(n.title)))
        n.id,
        n.title,
        n.summary,
        n.link,
        n.publisher,
        n.thumbnail_url,
        n.content_type,
        n.published_at
      FROM public.news_articles n
      WHERE n.title IS NOT NULL
        AND length(trim(n.title)) > 0
      ORDER BY lower(trim(n.title)), n.published_at DESC NULLS LAST
    ),
    latest_news AS (
      SELECT
        dn.id,
        dn.title,
        dn.summary,
        dn.link,
        dn.publisher,
        dn.thumbnail_url,
        dn.content_type,
        dn.published_at,
        COALESCE((
          SELECT jsonb_agg(DISTINCT link.ticker ORDER BY link.ticker)
          FROM public.news_article_tickers link
          WHERE link.article_id = dn.id
        ), '[]'::jsonb) AS related_tickers
      FROM dedup_news dn
      ORDER BY dn.published_at DESC NULLS LAST
      LIMIT 10
    ),
    news_symbols AS (
      SELECT DISTINCT jsonb_array_elements_text(ln.related_tickers) AS ticker
      FROM latest_news ln
    ),
    preview_symbols AS (
      SELECT ticker FROM top_gainers_cte
      UNION
      SELECT ticker FROM top_losers_cte
      UNION
      SELECT unnest(core_symbols) AS ticker
      UNION
      SELECT ticker FROM news_symbols
    ),
    enriched_quotes AS (
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
        f.fifty_two_week_low,
        COALESCE((
          SELECT jsonb_agg(h.close ORDER BY h.date ASC)
          FROM (
            SELECT sph.date, sph.close
            FROM public.stock_price_history sph
            WHERE sph.ticker = q.ticker
              AND sph.close IS NOT NULL
            ORDER BY sph.date DESC
            LIMIT 24
          ) h
        ), '[]'::jsonb) AS spark
      FROM preview_symbols ps
      JOIN public.stock_quotes q ON q.ticker = ps.ticker
      JOIN public.tickers t ON t.ticker = q.ticker
      LEFT JOIN public.stock_fundamentals f ON f.ticker = q.ticker
      WHERE q.price IS NOT NULL
    )
    SELECT jsonb_build_object(
      'quotes', COALESCE((
        SELECT jsonb_agg(to_jsonb(eq) ORDER BY eq.ticker)
        FROM enriched_quotes eq
      ), '[]'::jsonb),
      'top_gainers', COALESCE((
        SELECT jsonb_agg(to_jsonb(eq) ORDER BY eq.change_pct DESC NULLS LAST)
        FROM enriched_quotes eq
        JOIN top_gainers_cte g ON g.ticker = eq.ticker
      ), '[]'::jsonb),
      'top_losers', COALESCE((
        SELECT jsonb_agg(to_jsonb(eq) ORDER BY eq.change_pct ASC NULLS LAST)
        FROM enriched_quotes eq
        JOIN top_losers_cte l ON l.ticker = eq.ticker
      ), '[]'::jsonb),
      'news', COALESCE((
        SELECT jsonb_agg(to_jsonb(ln) ORDER BY ln.published_at DESC NULLS LAST)
        FROM latest_news ln
      ), '[]'::jsonb)
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.community_market_preview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.community_market_preview() TO authenticated;

COMMIT;
