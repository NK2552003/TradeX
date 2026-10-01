-- Canonical finance-kit tables. Full installation authority: database/schema.sql.
CREATE TABLE IF NOT EXISTS tickers (
    ticker      VARCHAR(20) PRIMARY KEY,
    market      VARCHAR(10),
    exchange    VARCHAR(20),
    currency    VARCHAR(5),
    asset_type  VARCHAR(20),
    name        TEXT,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tickers_market     ON tickers(market);
CREATE INDEX IF NOT EXISTS idx_tickers_asset_type ON tickers(asset_type);

CREATE TABLE IF NOT EXISTS stock_quotes (
    ticker         VARCHAR(20) PRIMARY KEY REFERENCES tickers(ticker) ON DELETE CASCADE,
    price          DECIMAL,
    previous_close DECIMAL,
    day_high       DECIMAL,
    day_low        DECIMAL,
    volume         BIGINT,
    change_pct     DECIMAL,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_fundamentals (
    ticker              VARCHAR(20) PRIMARY KEY REFERENCES tickers(ticker) ON DELETE CASCADE,
    market_cap          BIGINT,
    pe_ratio            DECIMAL,
    forward_pe          DECIMAL,
    peg_ratio           DECIMAL,
    eps                 DECIMAL,
    sector              VARCHAR(50),
    industry            VARCHAR(50),
    fifty_two_week_high DECIMAL,
    fifty_two_week_low  DECIMAL,
    fifty_day_average   DECIMAL,
    two_hundred_day_average DECIMAL,
    dividend_yield      DECIMAL,
    beta                DECIMAL,
    avg_volume          BIGINT,
    shares_outstanding  BIGINT,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_price_history (
    id          SERIAL PRIMARY KEY,
    ticker      VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    date        DATE NOT NULL,
    open        DECIMAL,
    high        DECIMAL,
    low         DECIMAL,
    close       DECIMAL,
    volume      BIGINT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (ticker, date)
);

CREATE INDEX IF NOT EXISTS idx_history_ticker_date ON stock_price_history(ticker, date);

CREATE TABLE IF NOT EXISTS news_articles (
    id             SERIAL PRIMARY KEY,
    title          TEXT,
    summary        TEXT,
    link           TEXT UNIQUE,
    publisher      VARCHAR(100),
    thumbnail_url  TEXT,
    content_type   VARCHAR(30),
    published_at   TIMESTAMPTZ,
    fetched_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_news_published ON news_articles(published_at DESC);

CREATE TABLE IF NOT EXISTS news_article_tickers (
    article_id  INTEGER NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    ticker      VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    PRIMARY KEY (article_id, ticker)
);

CREATE INDEX IF NOT EXISTS idx_article_tickers_ticker ON news_article_tickers(ticker);

CREATE TABLE IF NOT EXISTS news_topics (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS news_article_topics (
    article_id INTEGER NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    topic_id   INTEGER NOT NULL REFERENCES news_topics(id) ON DELETE CASCADE,
    PRIMARY KEY (article_id, topic_id)
);

CREATE TABLE IF NOT EXISTS screener_categories (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(50) UNIQUE NOT NULL,
    category_type VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS screener_results (
    id            SERIAL PRIMARY KEY,
    category_id   INTEGER NOT NULL REFERENCES screener_categories(id) ON DELETE CASCADE,
    ticker        VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    rank          INTEGER,
    price         DECIMAL,
    change_pct    DECIMAL,
    extra_data    JSONB,
    run_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_screener_results_category ON screener_results(category_id, rank);

CREATE TABLE IF NOT EXISTS index_metadata (
    ticker    VARCHAR(20) PRIMARY KEY REFERENCES tickers(ticker) ON DELETE CASCADE,
    continent VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS sector_metadata (
    ticker      VARCHAR(20) PRIMARY KEY REFERENCES tickers(ticker) ON DELETE CASCADE,
    sector_name VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS options_expirations (
    id              SERIAL PRIMARY KEY,
    ticker          VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    expiration_date DATE NOT NULL,
    fetched_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (ticker, expiration_date)
);

CREATE TABLE IF NOT EXISTS options_contracts (
    id                SERIAL PRIMARY KEY,
    expiration_id     INTEGER NOT NULL REFERENCES options_expirations(id) ON DELETE CASCADE,
    contract_type     VARCHAR(4) NOT NULL,
    strike            DECIMAL,
    last_price        DECIMAL,
    bid               DECIMAL,
    ask               DECIMAL,
    volume            BIGINT,
    open_interest     BIGINT,
    implied_volatility DECIMAL,
    in_the_money      BOOLEAN,
    contract_symbol   VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_options_contracts_expiration ON options_contracts(expiration_id, contract_type);

CREATE TABLE IF NOT EXISTS dividends (
    id      SERIAL PRIMARY KEY,
    ticker  VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    ex_date DATE NOT NULL,
    amount  DECIMAL,
    UNIQUE (ticker, ex_date)
);

CREATE TABLE IF NOT EXISTS stock_splits (
    id         SERIAL PRIMARY KEY,
    ticker     VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    split_date DATE NOT NULL,
    ratio      DECIMAL,
    UNIQUE (ticker, split_date)
);

CREATE TABLE IF NOT EXISTS analyst_recommendations (
    id        SERIAL PRIMARY KEY,
    ticker    VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    period    VARCHAR(10),
    strong_buy  INTEGER,
    buy         INTEGER,
    hold        INTEGER,
    sell        INTEGER,
    strong_sell INTEGER,
    fetched_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS holders (
    id          SERIAL PRIMARY KEY,
    ticker      VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    holder_type VARCHAR(20),
    holder_name TEXT,
    shares      BIGINT,
    date_reported DATE,
    pct_out     DECIMAL,
    value       BIGINT,
    fetched_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_holders_ticker ON holders(ticker, holder_type);


-- Full detail/screener JSON storage: migrations 023 and 024.
