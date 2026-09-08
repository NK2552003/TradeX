# Yahoo Finance News Fetcher — Standalone Kit

Full-detail financial news, grouped by topic approximations, with a rolling
7-day retention window.

## Read this first — an important limitation

Yahoo Finance's **website** organizes news into browsable sections:
"Markets", "Originals", "Newsletters", "Economy & Policy", "Tech", and
subtopics like "Stock market", "Crypto", "Tariffs", "Strait of Hormuz", etc.

**These topic categories are not available through any API — official or
unofficial.** They're rendered directly by Yahoo's website. There is no
endpoint anywhere that returns "all Tariffs news" or "all Economy & Policy
news." Every free/unofficial data source (including `yfinance`) only
exposes news **through a ticker** — e.g. "news related to AAPL" — not
"news in the Tech category."

### What this kit actually does
- Fetches full-detail news (title, summary, publisher, thumbnail, related
  tickers) **per ticker**.
- Groups tickers into topic-like buckets **that we defined ourselves** (see
  `TOPIC_TICKER_GROUPS` in `fetch_news.py`) to approximate a topic feed —
  e.g., energy company tickers stand in for an "Oil & Gas" feed. This is
  **not** Yahoo's actual editorial categorization, just a reasonable proxy.
- Keeps a genuine rolling 7-day window, deduped by article link, so nothing
  is lost between runs and nothing older than a week lingers.

### If you need real topic-categorized news
That requires either:
1. **A licensed news API** with actual topic/category tagging (e.g. a paid
   tier of NewsAPI, Finnhub, or similar), or
2. **Scraping Yahoo's actual web pages** directly — fragile, breaks
   whenever Yahoo changes their site, and likely against their Terms of
   Service. Not something this kit does.

---

## Usage

```bash
pip install yfinance --break-system-packages
python fetch_news.py
```

Output:
```
data/
├── all_news.json              # everything combined, rolling 7-day window
└── by_topic/
    ├── stock_market_general.json
    ├── crypto.json
    ├── magnificent_seven.json
    ├── oil_and_gas.json
    ├── aerospace_and_defense.json
    ├── enterprise_cloud.json
    ├── pharma_and_biotech.json
    ├── cybersecurity.json
    ├── clean_energy.json
    ├── housing.json
    └── banks_and_financials.json
```

## Editing the topic groups
Open `fetch_news.py` and edit `TOPIC_TICKER_GROUPS` near the top:
```python
TOPIC_TICKER_GROUPS = {
    "oil_and_gas": ["XOM", "CVX", "COP", "SLB", "OXY", "BP", "SHEL"],
    # add/remove groups and tickers as you like
}
```
Each group pulls news for every ticker in its list — more tickers per group
means broader (but less precisely on-topic) coverage.

## Article shape
```json
{
  "ticker": "XOM",
  "title": "Example headline",
  "summary": "Full article summary/description...",
  "link": "https://...",
  "publisher": "Reuters",
  "thumbnail_url": "https://...",
  "related_tickers": ["XOM"],
  "content_type": "STORY",
  "published_at": "2026-09-03T09:00:00+00:00"
}
```

## Retention
Controlled by `NEWS_RETENTION_DAYS = 7` near the top of `fetch_news.py`.
Each run merges new articles with whatever's already saved, drops anything
past the retention window, and dedupes by article link.

## Rate limiting
With 58 tickers (the default groups), one run makes 58 news requests to
Yahoo's endpoint. No artificial delay is added between them since news
requests are lighter than quote/history batch calls, but if you expand the
ticker groups significantly, consider adding a short `time.sleep()` between
requests to stay polite to Yahoo's servers.
