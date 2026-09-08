BEGIN;

-- Instruments
CREATE TABLE IF NOT EXISTS instruments (
    symbol TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    exchange TEXT,
    asset_class TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Quotes
CREATE TABLE IF NOT EXISTS quotes (
    symbol TEXT PRIMARY KEY REFERENCES instruments(symbol) ON DELETE CASCADE,
    price NUMERIC NOT NULL,
    previous_close NUMERIC,
    day_high NUMERIC,
    day_low NUMERIC,
    volume BIGINT,
    change_pct NUMERIC,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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

-- News Tickers
CREATE TABLE IF NOT EXISTS news_tickers (
    article_id UUID NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    symbol TEXT NOT NULL REFERENCES instruments(symbol) ON DELETE CASCADE,
    PRIMARY KEY (article_id, symbol)
);
CREATE INDEX IF NOT EXISTS idx_news_tickers_symbol ON news_tickers(symbol);

-- News Bookmarks
CREATE TABLE IF NOT EXISTS news_bookmarks (
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    article_id UUID NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, article_id)
);

-- Ticker Linking with Notes (Join Table instead of relying only on TEXT[])
CREATE TABLE IF NOT EXISTS note_ticker_links (
    note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE,
    symbol TEXT NOT NULL REFERENCES instruments(symbol) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (note_id, symbol)
);
CREATE INDEX IF NOT EXISTS idx_note_ticker_links_symbol ON note_ticker_links(symbol);
CREATE INDEX IF NOT EXISTS idx_note_ticker_links_user ON note_ticker_links(user_id);

-- Mirror sync for note_ticker_links -> trader_notes.linked_tickers
CREATE OR REPLACE FUNCTION sync_note_ticker_mirrors()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  n_id UUID := COALESCE(NEW.note_id, OLD.note_id);
BEGIN
  UPDATE trader_notes SET linked_tickers = COALESCE(
    (SELECT array_agg(symbol ORDER BY created_at DESC)
       FROM note_ticker_links WHERE note_id = n_id), '{}')
   WHERE id = n_id;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_note_ticker_links_sync ON note_ticker_links;
CREATE TRIGGER trg_note_ticker_links_sync
  AFTER INSERT OR DELETE ON note_ticker_links
  FOR EACH ROW EXECUTE FUNCTION sync_note_ticker_mirrors();

COMMIT;
