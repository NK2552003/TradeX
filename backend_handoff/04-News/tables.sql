-- News Articles

CREATE TABLE IF NOT EXISTS news_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    summary TEXT,
    publisher TEXT,
    url TEXT UNIQUE NOT NULL,
    thumbnail_url TEXT,
    content_type TEXT NOT NULL DEFAULT 'STORY',
    market TEXT,
    source TEXT,
    published_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_news_published ON news_articles(published_at DESC);

CREATE TABLE IF NOT EXISTS news_tickers (
    article_id UUID NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    symbol TEXT NOT NULL REFERENCES instruments(symbol) ON DELETE CASCADE,
    PRIMARY KEY (article_id, symbol)
);

CREATE INDEX IF NOT EXISTS idx_news_tickers_symbol ON news_tickers(symbol);

CREATE TABLE IF NOT EXISTS news_bookmarks (
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    article_id UUID NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, article_id)
);
