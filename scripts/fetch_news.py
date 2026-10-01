"""
Standalone News Fetcher — Yahoo Finance, full detail, rolling 7-day window.

IMPORTANT LIMITATION — read this first:
Yahoo Finance's WEBSITE organizes news into browsable topics/sections:
"Markets", "Originals", "Newsletters", "Economy & Policy", "Tech", and
further subtopics like "Stock market", "Crypto", "Tariffs", "Strait of
Hormuz", etc. (as seen in the app's navigation).

THESE TOPIC CATEGORIES ARE NOT AVAILABLE THROUGH ANY API. They are
rendered directly by Yahoo's website — there is no "give me all Tariffs
news" or "give me all Economy & Policy news" endpoint anywhere, official
or unofficial. yfinance (and every other free/unofficial wrapper) only
exposes news THROUGH A TICKER — i.e. "news related to AAPL", not
"news in the Tech category".

What this script actually does instead:
  - Fetches full-detail news (title, summary, publisher, thumbnail,
    related tickers) per ticker, for a list of tickers you provide.
  - You can approximate "topic" coverage by choosing tickers that
    represent a topic — e.g. energy company tickers for an "Oil & Gas"
    feed, or defense contractors for "Aerospace & Defense" — but this is
    ticker-based news, not Yahoo's actual editorial categorization.
  - Keeps a rolling 7-day window (not just today), deduped by article link.

If you need genuine topic-categorized news matching Yahoo's website
structure, that requires either:
  (a) A licensed news API with topic/category tagging (e.g. a paid tier
      of NewsAPI, Finnhub, or similar), or
  (b) Scraping Yahoo's actual web pages directly (fragile, likely against
      their Terms of Service, and not something this script does).

Usage:
    pip install yfinance --break-system-packages
    python fetch_news.py
"""

import json
import os
from asset_runtime import DATA_DIR as ASSET_DIR, read_json, write_json, merge_news
from datetime import datetime, timedelta, timezone

import yfinance as yf

DB_ENABLED = bool(os.environ.get("DATABASE_URL"))
if DB_ENABLED:
    import db as dbmod

DATA_DIR = str(ASSET_DIR)
NEWS_RETENTION_DAYS = 7
NEWS_LIMIT_PER_TICKER = 20  # Yahoo typically has 10-20 available per ticker

# ---------------------------------------------------------------------------
# Tickers to pull news for.
#
# Grouped into rough "topic approximations" — this is OUR grouping, not
# Yahoo's. Edit these freely to match what you actually want covered.
# ---------------------------------------------------------------------------

TOPIC_TICKER_GROUPS = {
    "stock_market_general": ["^GSPC", "^DJI", "^IXIC", "SPY", "QQQ"],
    "crypto": ["BTC-USD", "ETH-USD", "SOL-USD", "XRP-USD", "DOGE-USD"],
    "magnificent_seven": ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA"],
    "oil_and_gas": ["XOM", "CVX", "COP", "SLB", "OXY", "BP", "SHEL"],
    "aerospace_and_defense": ["BA", "LMT", "RTX", "NOC", "GD"],
    "enterprise_cloud": ["MSFT", "AMZN", "GOOGL", "CRM", "SNOW", "NOW"],
    "pharma_and_biotech": ["PFE", "MRK", "JNJ", "LLY", "ABBV", "MRNA"],
    "cybersecurity": ["CRWD", "PANW", "FTNT", "ZS", "OKTA"],
    "clean_energy": ["ENPH", "SEDG", "FSLR", "PLUG", "NEE"],
    "housing": ["DHI", "LEN", "PHM", "NVR", "KBH"],
    "banks_and_financials": ["JPM", "BAC", "WFC", "GS", "MS"],
}

ALL_TICKERS = sorted(set(t for group in TOPIC_TICKER_GROUPS.values() for t in group))


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def parse_published_at(raw):
    if raw is None:
        return None
    try:
        if isinstance(raw, (int, float)):
            return datetime.fromtimestamp(raw, tz=timezone.utc)
        cleaned = str(raw).replace("Z", "+00:00")
        return datetime.fromisoformat(cleaned)
    except Exception:
        return None


def fetch_news_for_ticker(ticker, limit=NEWS_LIMIT_PER_TICKER):
    try:
        articles = []
        for item in (yf.Ticker(ticker).news or [])[:limit]:
            content = item.get("content", item)
            published_dt = parse_published_at(content.get("pubDate") or item.get("providerPublishTime"))

            thumbnail = None
            thumb_block = content.get("thumbnail") or item.get("thumbnail")
            if isinstance(thumb_block, dict):
                resolutions = thumb_block.get("resolutions") or []
                thumbnail = resolutions[0].get("url") if resolutions else thumb_block.get("url")

            articles.append(
                {
                    "ticker": ticker,
                    "title": content.get("title") or item.get("title"),
                    "summary": content.get("summary") or content.get("description") or item.get("summary"),
                    "link": (content.get("canonicalUrl", {}) or {}).get("url") or item.get("link"),
                    "publisher": (content.get("provider", {}) or {}).get("displayName") or item.get("publisher"),
                    "thumbnail_url": thumbnail,
                    "related_tickers": content.get("relatedTickers") or item.get("relatedTickers") or [ticker],
                    "content_type": content.get("contentType") or item.get("type"),
                    "published_at": published_dt.isoformat() if published_dt else None,
                }
            )
        return articles
    except Exception as e:
        print(f"  [news] failed for {ticker}: {e}")
        return []


def merge_with_existing(path, new_articles):
    existing = []
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                existing = json.load(f)
        except Exception:
            existing = []

    combined = {a.get("link") or a.get("title"): a for a in merge_news(existing, new_articles)}

    cutoff = datetime.now(timezone.utc) - timedelta(days=NEWS_RETENTION_DAYS)
    result = [
        a for a in combined.values()
        if (parse_published_at(a.get("published_at")) or datetime.now(timezone.utc)) >= cutoff
    ]
    result.sort(key=lambda a: a.get("published_at") or "", reverse=True)
    return result


def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(os.path.join(DATA_DIR, "by_topic"), exist_ok=True)

    print(f"Fetching news for {len(ALL_TICKERS)} tickers across {len(TOPIC_TICKER_GROUPS)} topic groups...\n")

    conn = None
    if DB_ENABLED:
        conn = dbmod.get_connection()
        dbmod.init_schema(conn)
        print("  [db] connected — writing to Postgres in addition to JSON")

    # Which topic bucket(s) each ticker belongs to (a ticker can be in more than one)
    ticker_to_topics = {}
    for topic, tickers in TOPIC_TICKER_GROUPS.items():
        for t in tickers:
            ticker_to_topics.setdefault(t, []).append(topic)

    all_articles_by_ticker = {}
    for ticker in ALL_TICKERS:
        print(f"  {ticker}...")
        articles = fetch_news_for_ticker(ticker)
        all_articles_by_ticker[ticker] = articles

        if conn:
            for article in articles:
                dbmod.insert_news_article(conn, article, topic_names=ticker_to_topics.get(ticker, []))

    # Save per-topic-group files (grouping is ours, not Yahoo's — see module docstring)
    for topic, tickers in TOPIC_TICKER_GROUPS.items():
        topic_articles = []
        for t in tickers:
            topic_articles.extend(all_articles_by_ticker.get(t, []))

        path = os.path.join(DATA_DIR, "by_topic", f"{topic}.json")
        merged = merge_with_existing(path, topic_articles)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(merged, f, indent=2, default=str, ensure_ascii=False)
        print(f"  saved {path} ({len(merged)} articles, rolling {NEWS_RETENTION_DAYS}-day window)")

    # Also save one combined feed across everything
    everything = []
    for articles in all_articles_by_ticker.values():
        everything.extend(articles)
    combined_path = os.path.join(DATA_DIR, "all_news.json")
    merged_all = merge_with_existing(combined_path, everything)
    with open(combined_path, "w", encoding="utf-8") as f:
        json.dump(merged_all, f, indent=2, default=str, ensure_ascii=False)

    if conn:
        deleted = dbmod.cleanup_old_news(conn, days=NEWS_RETENTION_DAYS)
        print(f"  [db] cleanup: removed {deleted} news articles past {NEWS_RETENTION_DAYS} days")
        conn.close()

    print(f"\nDone. {len(merged_all)} total articles in the rolling {NEWS_RETENTION_DAYS}-day window.")
    print("Files written to ./data/ (all_news.json) and ./data/by_topic/*.json"
          + ("  [+ written to Postgres, linked to tickers + topics]" if DB_ENABLED else ""))


if __name__ == "__main__":
    main()
