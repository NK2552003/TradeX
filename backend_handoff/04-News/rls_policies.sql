ALTER TABLE news_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_tickers ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_bookmarks ENABLE ROW LEVEL SECURITY;

-- News articles and tickers are public read, backend-only write
CREATE POLICY news_articles_read ON news_articles FOR SELECT USING (true);
CREATE POLICY news_tickers_read ON news_tickers FOR SELECT USING (true);

-- Bookmarks are user-specific
CREATE POLICY news_bookmarks_select ON news_bookmarks FOR SELECT USING (user_id = auth.uid());
CREATE POLICY news_bookmarks_insert ON news_bookmarks FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY news_bookmarks_delete ON news_bookmarks FOR DELETE USING (user_id = auth.uid());
