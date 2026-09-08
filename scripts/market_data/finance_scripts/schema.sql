-- Finance data schema — designed for minimal storage via daily rewrite,
-- except news_articles, which keeps a rolling 7-day window of full-detail
-- articles (see NEWS_RETENTION_DAYS in fetch_finance_data.py).
--
-- STRATEGY:
--   stock_quotes       -> TRUNCATED + refilled every run. Always holds
--                          exactly "now's" full snapshot, never accumulates.
--   news_articles      -> ROLLING 7-DAY WINDOW. Upserted (deduped by link),
--                          NOT truncated -- cleanup_old_news() deletes
--                          anything older than 7 days after every run.
--   stock_fundamentals -> Overwritten in place per ticker (UPSERT), not
--                          truncated -- one row per ticker regardless of
--                          run count.
--   stock_price_history-> Append-only, but capped to a rolling 30-day window
--                          via a daily cleanup DELETE (needed for sparkline
--                          charts -- a single day of data can't render a trend).
--
-- Net effect: storage stays flat and bounded regardless of how often the
-- script runs or how long the app has been live.

CREATE TABLE IF NOT EXISTS stock_quotes (
    ticker         VARCHAR(15) PRIMARY KEY,
    market         VARCHAR(5)   NOT NULL,   -- 'US' or 'IN'
    exchange       VARCHAR(10),              -- 'NASDAQ','NYSE','NSE','BSE'
    currency       VARCHAR(5),               -- 'USD','INR'
    price          DECIMAL,
    previous_close DECIMAL,
    day_high       DECIMAL,
    day_low        DECIMAL,
    volume         BIGINT,
    change_pct     DECIMAL,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_fundamentals (
    ticker              VARCHAR(15) PRIMARY KEY,
    market              VARCHAR(5)   NOT NULL,
    exchange            VARCHAR(10),
    currency            VARCHAR(5),
    name                TEXT,
    market_cap          BIGINT,
    pe_ratio            DECIMAL,
    sector              VARCHAR(50),
    industry            VARCHAR(50),
    fifty_two_week_high DECIMAL,
    fifty_two_week_low  DECIMAL,
    dividend_yield      DECIMAL,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_price_history (
    id          SERIAL PRIMARY KEY,
    ticker      VARCHAR(15) NOT NULL,
    market      VARCHAR(5),
    currency    VARCHAR(5),
    date        DATE NOT NULL,
    open        DECIMAL,
    high        DECIMAL,
    low         DECIMAL,
    close       DECIMAL,
    volume      BIGINT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (ticker, date)                    -- one row per ticker per day
);

-- Full-detail news, rolling 7-day window (not daily-wiped -- see strategy above)
CREATE TABLE IF NOT EXISTS news_articles (
    id               SERIAL PRIMARY KEY,
    ticker           VARCHAR(15),
    market           VARCHAR(5),
    title            TEXT,
    summary          TEXT,                  -- full article summary/description
    link             TEXT UNIQUE,             -- unique -> enables dedupe via upsert
    publisher        VARCHAR(100),
    thumbnail_url    TEXT,
    related_tickers  JSONB,                   -- array of tickers this article relates to
    content_type     VARCHAR(30),             -- e.g. 'STORY', 'VIDEO'
    published_at     TIMESTAMPTZ,
    fetched_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quotes_market       ON stock_quotes(market);
CREATE INDEX IF NOT EXISTS idx_fundamentals_market ON stock_fundamentals(market);
CREATE INDEX IF NOT EXISTS idx_history_ticker_date ON stock_price_history(ticker, date);
CREATE INDEX IF NOT EXISTS idx_news_published       ON news_articles(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_ticker          ON news_articles(ticker);
