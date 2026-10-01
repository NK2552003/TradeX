-- Parameter placeholders are bound by the consuming API, never concatenated.
SELECT t.ticker, t.name, t.market, t.currency, q.*
FROM tickers t JOIN stock_quotes q USING(ticker)
WHERE (:market IS NULL OR t.market = :market)
ORDER BY t.ticker LIMIT :limit OFFSET :offset;
SELECT date, open, high, low, close, volume FROM stock_price_history
WHERE ticker = :ticker ORDER BY date;
SELECT detail, fetched_at FROM stock_details WHERE ticker = :ticker;
SELECT c.name, c.category_type, s.payload, s.exported_at
FROM screener_categories c JOIN market_screener_snapshots s ON s.category_id = c.id
ORDER BY c.name;
SELECT r.rank, t.ticker, t.name, r.price, r.change_pct, r.extra_data
FROM screener_results r JOIN screener_categories c ON c.id = r.category_id
JOIN tickers t ON t.ticker = r.ticker WHERE c.name = :category ORDER BY r.rank
LIMIT :limit OFFSET :offset;
