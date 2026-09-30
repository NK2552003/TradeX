-- News articles use the canonical main-branch schema.

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

CREATE TABLE IF NOT EXISTS news_tickers (
    article_id INTEGER NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    symbol TEXT NOT NULL REFERENCES instruments(symbol) ON DELETE CASCADE,
    PRIMARY KEY (article_id, symbol)
);

CREATE INDEX IF NOT EXISTS idx_news_tickers_symbol ON news_tickers(symbol);

CREATE TABLE IF NOT EXISTS news_bookmarks (
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    article_id INTEGER NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, article_id)
);
