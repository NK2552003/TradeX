"""
Finance News Kit — Dedicated News Fetcher with Topic Categories.
Fetches live ticker news via yfinance if available, or generates mock news if offline.
Outputs directly to `assets/data/` (including `by_topic/*.json` and `all_news.json`).
"""

import json
import os
from datetime import datetime, timedelta, timezone

try:
    import yfinance as yf
    YFINANCE_AVAILABLE = True
except ImportError:
    YFINANCE_AVAILABLE = False

DB_ENABLED = bool(os.environ.get("DATABASE_URL"))
if DB_ENABLED:
    try:
        import db as dbmod
    except ImportError:
        DB_ENABLED = False

SCRIPT_DIR = os.path.dirname(__file__)
OUT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "assets", "data"))
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(os.path.join(OUT_DIR, "by_topic"), exist_ok=True)

TOPIC_GROUPS = {
    "stock_market_general": ["^GSPC", "^DJI", "^IXIC", "SPY", "QQQ"],
    "crypto": ["BTC-USD", "ETH-USD", "SOL-USD", "XRP-USD"],
    "magnificent_seven": ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA"],
    "oil_and_gas": ["XOM", "CVX", "RELIANCE.NS"],
    "pharma_and_biotech": ["PFE", "MRK", "JNJ"],
    "banks_and_financials": ["JPM", "BAC", "HDFCBANK.NS", "ICICIBANK.NS"],
}

NEWS_RETENTION_DAYS = 7


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def get_market(ticker):
    if ticker.startswith("^"):
        return "INDEX"
    if ticker.endswith("-USD"):
        return "CRYPTO"
    if ticker.endswith(".NS") or ticker.endswith(".BO"):
        return "IN"
    return "US"


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


def fetch_news_for_ticker_live(ticker, limit=10):
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

            articles.append({
                "ticker": ticker,
                "market": get_market(ticker),
                "title": content.get("title") or item.get("title"),
                "summary": content.get("summary") or content.get("description") or item.get("summary"),
                "link": (content.get("canonicalUrl", {}) or {}).get("url") or item.get("link"),
                "publisher": (content.get("provider", {}) or {}).get("displayName") or item.get("publisher"),
                "thumbnail_url": thumbnail,
                "related_tickers": content.get("relatedTickers") or item.get("relatedTickers") or [ticker],
                "content_type": content.get("contentType") or item.get("type") or "STORY",
                "published_at": published_dt.isoformat() if published_dt else now_iso(),
            })
        return articles
    except Exception as e:
        print(f"  [news] live fetch failed for {ticker}: {e}")
        return []


def generate_mock_news():
    articles = [
        {
            "ticker": "RELIANCE.NS",
            "market": "IN",
            "title": "Reliance Retail Expands Digital Platform Integration Across Key Markets",
            "summary": "Strong quarterly performance driven by digital commerce acceleration and expanded footprint in retail and consumer services.",
            "link": "https://finance.yahoo.com/news/example-reliance",
            "publisher": "Reuters",
            "thumbnail_url": "https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=500",
            "related_tickers": ["RELIANCE.NS", "TCS.NS"],
            "content_type": "STORY",
            "published_at": now_iso()
        },
        {
            "ticker": "AAPL",
            "market": "US",
            "title": "Apple Prepares Next-Gen Silicon Upgrades for Flagship Lineup",
            "summary": "Analyst sentiment turns bullish following supply chain updates indicating strong yield performance on 3nm nodes.",
            "link": "https://finance.yahoo.com/news/example-apple",
            "publisher": "Bloomberg",
            "thumbnail_url": "https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?w=500",
            "related_tickers": ["AAPL", "MSFT", "NVDA"],
            "content_type": "STORY",
            "published_at": now_iso()
        },
        {
            "ticker": "NVDA",
            "market": "US",
            "title": "AI Hardware Demand Surges Ahead of Quarterly Earnings",
            "summary": "Data center revenue accelerates as cloud providers ramp up infrastructure spending for large language model training.",
            "link": "https://finance.yahoo.com/news/example-nvda",
            "publisher": "CNBC",
            "thumbnail_url": "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500",
            "related_tickers": ["NVDA", "MSFT", "AMZN"],
            "content_type": "STORY",
            "published_at": now_iso()
        },
        {
            "ticker": "BTC-USD",
            "market": "CRYPTO",
            "title": "Bitcoin Holds Key Support Level as Market Liquidity Expands",
            "summary": "Institutional inflows into spot ETFs reach new monthly high while long-term holder balances remain steady.",
            "link": "https://finance.yahoo.com/news/example-btc",
            "publisher": "CoinDesk",
            "thumbnail_url": "https://images.unsplash.com/photo-1518770660439-4636190af475?w=500",
            "related_tickers": ["BTC-USD", "ETH-USD"],
            "content_type": "STORY",
            "published_at": now_iso()
        }
    ]

    by_topic = {
        "stock_market_general": articles[:2],
        "crypto": [articles[3]],
        "magnificent_seven": [articles[1], articles[2]],
        "oil_and_gas": [articles[0]],
        "pharma_and_biotech": [articles[1]],
        "banks_and_financials": [articles[0]]
    }

    return articles, by_topic


def save_json(target_filename, data):
    path = os.path.join(OUT_DIR, target_filename)
    parent = os.path.dirname(path)
    os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, default=str, ensure_ascii=False)
    print(f"  saved {path}")


def main():
    print("[Finance News Kit] Running news fetcher...")
    all_articles = []
    by_topic = {}

    if YFINANCE_AVAILABLE:
        try:
            print("  Fetching live news via yfinance...")
            for topic_name, tickers in TOPIC_GROUPS.items():
                topic_articles = []
                for ticker in tickers:
                    articles = fetch_news_for_ticker_live(ticker)
                    topic_articles.extend(articles)
                    all_articles.extend(articles)
                by_topic[topic_name] = topic_articles
        except Exception as e:
            print(f"  Live news fetch failed: {e}. Falling back to mock news.")
            all_articles = []

    if not all_articles:
        all_articles, by_topic = generate_mock_news()

    # Deduplicate all articles by link
    seen_links = set()
    deduped_all = []
    for article in all_articles:
        link = article.get("link")
        if link and link not in seen_links:
            seen_links.add(link)
            deduped_all.append(article)
        elif not link:
            deduped_all.append(article)

    save_json("all_news.json", deduped_all)
    save_json("news.json", deduped_all)

    for topic_name, articles in by_topic.items():
        save_json(os.path.join("by_topic", f"{topic_name}.json"), articles)

    if DB_ENABLED:
        try:
            conn = dbmod.get_connection()
            dbmod.init_schema(conn)
            for article in deduped_all:
                dbmod.insert_news_article(conn, article)
            conn.close()
            print("  [db] Wrote news articles to Postgres successfully.")
        except Exception as e:
            print(f"  [db] Postgres news write failed: {e}")

    print("[Finance News Kit] Completed successfully.")


if __name__ == "__main__":
    main()
