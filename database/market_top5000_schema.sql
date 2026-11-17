-- ============================================================================
-- Market Intelligence — Top 5,000 US Tickers Schema & Smart-Update Indexes
-- Run this SQL file in the Supabase SQL Editor to create any missing tables,
-- add natural-key unique indexes for smart upserts, grant read access, and
-- clean up legacy rows outside the top-5000 universe.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.market_universe (
  ticker         VARCHAR(20) PRIMARY KEY,
  display_symbol VARCHAR(20) NOT NULL,
  rank           INTEGER NOT NULL CHECK (rank BETWEEN 1 AND 5000),
  name           TEXT NOT NULL,
  exchange       VARCHAR(20),
  sector         VARCHAR(50),
  market_cap     BIGINT,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_market_universe_rank
  ON public.market_universe (rank);

CREATE TABLE IF NOT EXISTS public.tickers (
  ticker        VARCHAR(20) PRIMARY KEY,
  market        VARCHAR(10),
  exchange      VARCHAR(20),
  currency      VARCHAR(5),
  asset_type    VARCHAR(20),
  name          TEXT,
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stock_quotes (
  ticker         VARCHAR(20) PRIMARY KEY REFERENCES public.tickers(ticker) ON DELETE CASCADE,
  price          DECIMAL,
  previous_close DECIMAL,
  day_high       DECIMAL,
  day_low        DECIMAL,
  volume         BIGINT,
  change_pct     DECIMAL,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stock_fundamentals (
  ticker                  VARCHAR(20) PRIMARY KEY REFERENCES public.tickers(ticker) ON DELETE CASCADE,
  market_cap              BIGINT,
  pe_ratio                DECIMAL,
  forward_pe              DECIMAL,
  peg_ratio               DECIMAL,
  eps                     DECIMAL,
  sector                  VARCHAR(50),
  industry                VARCHAR(50),
  fifty_two_week_high     DECIMAL,
  fifty_two_week_low      DECIMAL,
  fifty_day_average       DECIMAL,
  two_hundred_day_average DECIMAL,
  dividend_yield          DECIMAL,
  beta                    DECIMAL,
  avg_volume              BIGINT,
  shares_outstanding      BIGINT,
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stock_price_history (
  id          SERIAL PRIMARY KEY,
  ticker      VARCHAR(20) NOT NULL REFERENCES public.tickers(ticker) ON DELETE CASCADE,
  date        DATE NOT NULL,
  open        DECIMAL,
  high        DECIMAL,
  low         DECIMAL,
  close       DECIMAL,
  volume      BIGINT,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (ticker, date)
);

CREATE INDEX IF NOT EXISTS idx_history_ticker_date
  ON public.stock_price_history (ticker, date DESC);

CREATE TABLE IF NOT EXISTS public.stock_details (
  ticker     VARCHAR(20) PRIMARY KEY REFERENCES public.tickers(ticker) ON DELETE CASCADE,
  detail     JSONB NOT NULL CHECK (jsonb_typeof(detail) = 'object' AND detail->>'ticker' = ticker),
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.options_expirations (
  id              SERIAL PRIMARY KEY,
  ticker          VARCHAR(20) NOT NULL REFERENCES public.tickers(ticker) ON DELETE CASCADE,
  expiration_date DATE NOT NULL,
  fetched_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (ticker, expiration_date)
);

CREATE TABLE IF NOT EXISTS public.options_contracts (
  id                 SERIAL PRIMARY KEY,
  expiration_id      INTEGER NOT NULL REFERENCES public.options_expirations(id) ON DELETE CASCADE,
  contract_type      VARCHAR(4) NOT NULL,
  strike             DECIMAL,
  last_price         DECIMAL,
  bid                DECIMAL,
  ask                DECIMAL,
  volume             BIGINT,
  open_interest      BIGINT,
  implied_volatility DECIMAL,
  in_the_money       BOOLEAN,
  contract_symbol    VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_options_contracts_expiration
  ON public.options_contracts (expiration_id, contract_type);

CREATE TABLE IF NOT EXISTS public.dividends (
  id      SERIAL PRIMARY KEY,
  ticker  VARCHAR(20) NOT NULL REFERENCES public.tickers(ticker) ON DELETE CASCADE,
  ex_date DATE NOT NULL,
  amount  DECIMAL,
  UNIQUE (ticker, ex_date)
);

CREATE TABLE IF NOT EXISTS public.stock_splits (
  id         SERIAL PRIMARY KEY,
  ticker     VARCHAR(20) NOT NULL REFERENCES public.tickers(ticker) ON DELETE CASCADE,
  split_date DATE NOT NULL,
  ratio      DECIMAL,
  UNIQUE (ticker, split_date)
);

CREATE TABLE IF NOT EXISTS public.analyst_recommendations (
  id          SERIAL PRIMARY KEY,
  ticker      VARCHAR(20) NOT NULL REFERENCES public.tickers(ticker) ON DELETE CASCADE,
  period      VARCHAR(10) NOT NULL,
  strong_buy  INTEGER,
  buy         INTEGER,
  hold        INTEGER,
  sell        INTEGER,
  strong_sell INTEGER,
  fetched_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

DELETE FROM public.analyst_recommendations a
  USING public.analyst_recommendations b
  WHERE a.ticker = b.ticker AND a.period IS NOT DISTINCT FROM b.period AND a.id < b.id;

CREATE UNIQUE INDEX IF NOT EXISTS uq_analyst_recommendations_ticker_period
  ON public.analyst_recommendations (ticker, period);

CREATE TABLE IF NOT EXISTS public.holders (
  id            SERIAL PRIMARY KEY,
  ticker        VARCHAR(20) NOT NULL REFERENCES public.tickers(ticker) ON DELETE CASCADE,
  holder_type   VARCHAR(30) NOT NULL,
  holder_name   TEXT NOT NULL,
  shares        BIGINT,
  date_reported DATE,
  pct_out       DECIMAL,
  value         BIGINT,
  fetched_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.holders ALTER COLUMN holder_type TYPE VARCHAR(30);

DELETE FROM public.holders a
  USING public.holders b
  WHERE a.ticker = b.ticker AND a.holder_type IS NOT DISTINCT FROM b.holder_type
    AND a.holder_name IS NOT DISTINCT FROM b.holder_name AND a.id < b.id;

CREATE UNIQUE INDEX IF NOT EXISTS uq_holders_ticker_type_name
  ON public.holders (ticker, holder_type, holder_name);

CREATE UNIQUE INDEX IF NOT EXISTS uq_options_contracts_exp_symbol
  ON public.options_contracts (expiration_id, contract_symbol)
  WHERE contract_symbol IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_screener_results_cat_ticker_run
  ON public.screener_results (category_id, ticker, run_at);

CREATE INDEX IF NOT EXISTS idx_holders_ticker
  ON public.holders (ticker, holder_type);

CREATE TABLE IF NOT EXISTS public.news_articles (
  id            SERIAL PRIMARY KEY,
  title         TEXT,
  summary       TEXT,
  link          TEXT UNIQUE,
  publisher     VARCHAR(100),
  thumbnail_url TEXT,
  content_type  VARCHAR(30),
  published_at  TIMESTAMPTZ,
  fetched_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_news_published
  ON public.news_articles (published_at DESC);

CREATE TABLE IF NOT EXISTS public.news_article_tickers (
  article_id INTEGER NOT NULL REFERENCES public.news_articles(id) ON DELETE CASCADE,
  ticker     VARCHAR(20) NOT NULL REFERENCES public.tickers(ticker) ON DELETE CASCADE,
  PRIMARY KEY (article_id, ticker)
);

CREATE INDEX IF NOT EXISTS idx_article_tickers_ticker
  ON public.news_article_tickers (ticker);

CREATE TABLE IF NOT EXISTS public.screener_categories (
  id            SERIAL PRIMARY KEY,
  name          VARCHAR(60) UNIQUE NOT NULL,
  category_type VARCHAR(20) NOT NULL DEFAULT 'GLOBAL'
);

CREATE TABLE IF NOT EXISTS public.screener_results (
  id          SERIAL PRIMARY KEY,
  category_id INTEGER NOT NULL REFERENCES public.screener_categories(id) ON DELETE CASCADE,
  ticker      VARCHAR(20) NOT NULL REFERENCES public.tickers(ticker) ON DELETE CASCADE,
  rank        INTEGER,
  price       DECIMAL,
  change_pct  DECIMAL,
  extra_data  JSONB,
  run_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_screener_results_category
  ON public.screener_results (category_id, rank);

CREATE TABLE IF NOT EXISTS public.market_screener_snapshots (
  category_id INTEGER PRIMARY KEY REFERENCES public.screener_categories(id) ON DELETE CASCADE,
  payload     JSONB NOT NULL,
  exported_at TIMESTAMPTZ NOT NULL,
  CHECK (jsonb_typeof(payload) IN ('object', 'array'))
);

-- Row-Level Security & read grants for both authenticated and anon clients
ALTER TABLE public.market_universe ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.market_screener_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dividends ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analyst_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.holders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.options_expirations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.options_contracts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS market_universe_read ON public.market_universe;
CREATE POLICY market_universe_read ON public.market_universe
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS stock_details_read ON public.stock_details;
CREATE POLICY stock_details_read ON public.stock_details
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS market_screener_snapshots_read ON public.market_screener_snapshots;
CREATE POLICY market_screener_snapshots_read ON public.market_screener_snapshots
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS dividends_read ON public.dividends;
CREATE POLICY dividends_read ON public.dividends
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS stock_splits_read ON public.stock_splits;
CREATE POLICY stock_splits_read ON public.stock_splits
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS analyst_recommendations_read ON public.analyst_recommendations;
CREATE POLICY analyst_recommendations_read ON public.analyst_recommendations
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS holders_read ON public.holders;
CREATE POLICY holders_read ON public.holders
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS options_expirations_read ON public.options_expirations;
CREATE POLICY options_expirations_read ON public.options_expirations
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS options_contracts_read ON public.options_contracts;
CREATE POLICY options_contracts_read ON public.options_contracts
  FOR SELECT TO anon, authenticated USING (true);

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
TO anon, authenticated;

-- Clean start: wipe all existing Market Intelligence data & reset IDs so there is zero legacy/duplicate data
TRUNCATE TABLE
  public.market_universe,
  public.tickers,
  public.stock_quotes,
  public.stock_fundamentals,
  public.stock_price_history,
  public.stock_details,
  public.options_expirations,
  public.options_contracts,
  public.dividends,
  public.stock_splits,
  public.analyst_recommendations,
  public.holders,
  public.news_articles,
  public.news_article_tickers,
  public.screener_categories,
  public.screener_results,
  public.market_screener_snapshots
RESTART IDENTITY CASCADE;

-- Drop unused legacy market tables (keep `instruments` as `note_ticker_links` references it)
DROP TABLE IF EXISTS public.news_article_topics;
DROP TABLE IF EXISTS public.news_topics;
DROP TABLE IF EXISTS public.index_metadata;
DROP TABLE IF EXISTS public.sector_metadata;
DROP TABLE IF EXISTS public.quotes;
DROP TABLE IF EXISTS public.news_tickers;
DROP TABLE IF EXISTS public.market_history;

NOTIFY pgrst, 'reload schema';

COMMIT;
