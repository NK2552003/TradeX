"""
Finance Data Fetcher — scales to thousands of tickers (US + India) using
batched requests, saves to local JSON files, and optionally to Postgres.

WHY THIS VERSION IS DIFFERENT FROM THE 100-TICKER VERSION:
At 8,000 tickers, fetching one-ticker-at-a-time (yf.Ticker per symbol) is
too slow and too likely to get rate-limited. This version:
  1. Loads tickers from tickers/us_tickers.csv + tickers/in_tickers.csv
     (generate these once with fetch_ticker_lists.py), falling back to a
     small built-in list if those files don't exist.
  2. Fetches quotes + price history in BATCHES via yf.download(), which is
     dramatically faster than one call per ticker.
  3. Skips full fundamentals (.info) for the entire universe by default —
     that call is slow and mostly unnecessary at this scale. Fundamentals
     are fetched only for a capped subset (FUNDAMENTALS_LIMIT), meant to
     represent your app's actively-watchlisted tickers, not all 8,000.
  4. Skips per-ticker news for the entire universe too, for the same
     reason — news is capped to a subset (NEWS_TICKER_LIMIT).

Usage:
    pip install yfinance --break-system-packages
    python fetch_ticker_lists.py      # one-time: download full ticker universe
    python fetch_finance_data.py      # fetch quotes/history for everyone,
                                       # fundamentals/news for the capped subset

With Postgres:
    pip install psycopg2-binary --break-system-packages
    export DATABASE_URL=postgresql://postgres:devpass@localhost:5432/financeapp
    python fetch_finance_data.py

Storage strategy (see schema.sql): stock_quotes and news_articles are
truncated + refilled every run; stock_fundamentals is upserted per ticker;
stock_price_history keeps a rolling 30-day window, auto-cleaned.
"""

import csv
import json
import math
import os
from asset_runtime import DATA_DIR as ASSET_DIR, read_json, write_json, merge_news
import time
from datetime import datetime, timedelta, timezone

import yfinance as yf

# Optional Postgres backend — only imported/used if DATABASE_URL is set.
DB_ENABLED = bool(os.environ.get("DATABASE_URL"))
if DB_ENABLED:
    import db as dbmod

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

TICKERS_DIR = str(ASSET_DIR / "tickers")
US_TICKERS_CSV = os.path.join(TICKERS_DIR, "us_tickers.csv")
IN_TICKERS_CSV = os.path.join(TICKERS_DIR, "in_tickers.csv")

# Fallback if you haven't run fetch_ticker_lists.py yet
FALLBACK_US_TICKERS = ["AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "NVDA"]
FALLBACK_IN_TICKERS = ["RELIANCE.NS", "TCS.NS", "INFY.NS", "HDFCBANK.NS", "ICICIBANK.NS"]

BATCH_SIZE = 100          # tickers per yf.download() call — keeps each request manageable
BATCH_PAUSE_SECONDS = 2   # pause between batches, be polite to Yahoo's endpoint

# Fundamentals (.info) and per-ticker news are slow — cap them to a subset.
# In a real app, this subset should be "tickers the user actually watches",
# not the full universe. Edit these numbers, or replace with a real
# watchlist query, once you're past prototyping.
FUNDAMENTALS_LIMIT = int(os.environ.get("FUNDAMENTALS_LIMIT", "300"))
NEWS_TICKER_LIMIT = int(os.environ.get("NEWS_TICKER_LIMIT", "100"))       # how many tickers get news fetched (cap for scale)
NEWS_LIMIT_PER_TICKER = 10    # articles per ticker — yfinance typically has ~10-20 available
NEWS_RETENTION_DAYS = 7        # keep the full week, not just today's pool

DATA_DIR = str(ASSET_DIR)
HISTORY_DIR = os.path.join(DATA_DIR, "history")


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def is_nan(val):
    try:
        return math.isnan(val)
    except (TypeError, ValueError):
        return val is None


# ---------------------------------------------------------------------------
# Ticker loading
# ---------------------------------------------------------------------------


def load_tickers_from_csv(path, fallback):
    if not os.path.exists(path):
        print(f"  [tickers] {path} not found — using small fallback list. "
              f"Run fetch_ticker_lists.py to get the full universe.")
        return fallback
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        tickers = [row["ticker"].strip() for row in reader if row.get("ticker")]
    print(f"  [tickers] loaded {len(tickers)} tickers from {path}")
    return tickers


US_TICKERS = load_tickers_from_csv(US_TICKERS_CSV, FALLBACK_US_TICKERS)
INDIA_TICKERS = load_tickers_from_csv(IN_TICKERS_CSV, FALLBACK_IN_TICKERS)
ALL_TICKERS = list(dict.fromkeys(list(read_json(ASSET_DIR / "quotes.json", {})) + US_TICKERS + INDIA_TICKERS))
if os.environ.get("MARKET_TICKER_LIMIT"):
    ALL_TICKERS = ALL_TICKERS[:int(os.environ["MARKET_TICKER_LIMIT"])]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def ensure_dirs():
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(HISTORY_DIR, exist_ok=True)


def save_json(path, data):
    write_json(path, data)


def get_market(ticker):
    return "IN" if ticker.endswith(".NS") or ticker.endswith(".BO") else "US"


def get_currency(ticker):
    return "INR" if get_market(ticker) == "IN" else "USD"


def get_exchange(ticker):
    if ticker.endswith(".NS"):
        return "NSE"
    if ticker.endswith(".BO"):
        return "BSE"
    return "US"


def chunked(seq, size):
    for i in range(0, len(seq), size):
        yield seq[i : i + size]


# ---------------------------------------------------------------------------
# Batched quotes + history (the scalable path — used for ALL tickers)
# ---------------------------------------------------------------------------


def fetch_batch_quotes_and_history(tickers, period="1mo", interval="1d"):
    """
    One yf.download() call per batch returns both the latest price (last row)
    and the full history (all rows) for every ticker in the batch — far
    faster than calling yf.Ticker() once per symbol.
    Returns (quotes_dict, history_dict).

    IMPORTANT: current yfinance defaults `multi_level_index=True` even when
    only ONE ticker is requested — so a single-ticker batch (e.g. a leftover
    remainder batch) still comes back multi-indexed, not flat. Older code
    that branched on `len(tickers) > 1` to decide flat-vs-multi-index broke
    on exactly this case. Explicitly passing `multi_level_index=False` below
    removes the ambiguity — group_by="ticker" always gives us `data[ticker]`
    consistently, regardless of batch size.
    """
    quotes = {}
    history = {}

    try:
        data = yf.download(
            tickers,
            period=period,
            interval=interval,
            group_by="ticker",
            threads=True,
            progress=False,
            multi_level_index=False,  # pin the shape explicitly — don't rely on ticker-count branching
        )
    except Exception as e:
        print(f"  [batch] download failed for batch starting with {tickers[0]}: {e}")
        return quotes, history

    for ticker in tickers:
        try:
            # With multi_level_index=False and group_by="ticker", a single-ticker
            # batch returns a flat frame (no ticker-level column), while a
            # multi-ticker batch still needs data[ticker]. Try the multi-ticker
            # path first, fall back to treating `data` itself as this ticker's
            # frame — this handles both shapes without guessing from len(tickers).
            try:
                df = data[ticker]
            except (KeyError, TypeError):
                df = data

            df = df.dropna(how="all")
            if df.empty:
                continue

            df = df.dropna(subset=["Open", "High", "Low", "Close"])
            if df.empty:
                continue
            records = []
            for date, row in df.iterrows():
                records.append(
                    {
                        "date": date.isoformat(),
                        "open": round(float(row["Open"]), 2),
                        "high": round(float(row["High"]), 2),
                        "low": round(float(row["Low"]), 2),
                        "close": round(float(row["Close"]), 2),
                        "volume": 0 if is_nan(row["Volume"]) else int(row["Volume"]),
                    }
                )

            history[ticker] = {
                "ticker": ticker,
                "market": get_market(ticker),
                "currency": get_currency(ticker),
                "period": period,
                "interval": interval,
                "data": records,
            }

            last = df.iloc[-1]
            prev = df.iloc[-2] if len(df) > 1 else None
            price = round(float(last["Close"]), 2)
            previous_close = round(float(prev["Close"]), 2) if prev is not None else None
            change_pct = (
                round((price - previous_close) / previous_close * 100, 2)
                if previous_close
                else None
            )

            quotes[ticker] = {
                "ticker": ticker,
                "market": get_market(ticker),
                "exchange": get_exchange(ticker),
                "currency": get_currency(ticker),
                "price": price,
                "previous_close": previous_close,
                "day_high": round(float(last["High"]), 2),
                "day_low": round(float(last["Low"]), 2),
                "volume": 0 if is_nan(last["Volume"]) else int(last["Volume"]),
                "change_pct": change_pct,
                "updated_at": now_iso(),
            }
        except Exception as e:
            print(f"  [batch] parse failed for {ticker}: {e}")
            continue

    return quotes, history


# ---------------------------------------------------------------------------
# Fundamentals + news (slow, per-ticker — capped to a subset, NOT the full universe)
# ---------------------------------------------------------------------------


def fetch_fundamentals(ticker):
    try:
        info = yf.Ticker(ticker).info
        return {
            "ticker": ticker,
            "market": get_market(ticker),
            "exchange": get_exchange(ticker),
            "currency": get_currency(ticker),
            "name": info.get("longName") or info.get("shortName"),
            "market_cap": info.get("marketCap"),
            "pe_ratio": info.get("trailingPE"),
            "sector": info.get("sector"),
            "industry": info.get("industry"),
            "fifty_two_week_high": info.get("fiftyTwoWeekHigh"),
            "fifty_two_week_low": info.get("fiftyTwoWeekLow"),
            "dividend_yield": info.get("dividendYield"),
            "updated_at": now_iso(),
        }
    except Exception as e:
        print(f"  [fundamentals] failed for {ticker}: {e}")
        return None


def parse_published_at(raw):
    """
    Normalizes yfinance's published-time field, which varies by version:
    sometimes an epoch int, sometimes an ISO string. Returns a
    timezone-aware datetime, or None if unparseable.
    """
    if raw is None:
        return None
    try:
        # epoch seconds (int/float)
        if isinstance(raw, (int, float)):
            return datetime.fromtimestamp(raw, tz=timezone.utc)
        # ISO string, e.g. "2026-09-03T09:00:00Z"
        cleaned = str(raw).replace("Z", "+00:00")
        return datetime.fromisoformat(cleaned)
    except Exception:
        return None


def fetch_news(ticker, limit=10):
    """
    Full-detail news per ticker: title, summary, publisher, thumbnail,
    related tickers, and normalized published_at — not just a headline+link.
    """
    try:
        articles = []
        for item in (yf.Ticker(ticker).news or [])[:limit]:
            content = item.get("content", item)

            published_raw = content.get("pubDate") or item.get("providerPublishTime")
            published_dt = parse_published_at(published_raw)

            thumbnail = None
            thumb_block = content.get("thumbnail") or item.get("thumbnail")
            if isinstance(thumb_block, dict):
                resolutions = thumb_block.get("resolutions") or []
                if resolutions:
                    thumbnail = resolutions[0].get("url")
                else:
                    thumbnail = thumb_block.get("url")

            related = (
                content.get("relatedTickers")
                or item.get("relatedTickers")
                or [ticker]
            )

            articles.append(
                {
                    "ticker": ticker,
                    "market": get_market(ticker),
                    "title": content.get("title") or item.get("title"),
                    "summary": content.get("summary") or content.get("description") or item.get("summary"),
                    "link": (content.get("canonicalUrl", {}) or {}).get("url") or item.get("link"),
                    "publisher": (content.get("provider", {}) or {}).get("displayName")
                    or item.get("publisher"),
                    "thumbnail_url": thumbnail,
                    "related_tickers": related,
                    "content_type": content.get("contentType") or item.get("type"),
                    "published_at": published_dt.isoformat() if published_dt else None,
                }
            )
        return articles
    except Exception as e:
        print(f"  [news] failed for {ticker}: {e}")
        return []


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    ensure_dirs()
    print(f"Tracking {len(ALL_TICKERS)} tickers total "
          f"({len(US_TICKERS)} US + {len(INDIA_TICKERS)} India)")
    print(f"Fundamentals will be fetched for the first {FUNDAMENTALS_LIMIT} tickers only.")
    print(f"News will be fetched for the first {NEWS_TICKER_LIMIT} tickers only.\n")

    conn = None
    if DB_ENABLED:
        conn = dbmod.get_connection()
        dbmod.init_schema(conn)
        dbmod.reset_quotes(conn)  # only quotes reset — news is a rolling window, not wiped
        print("  [db] connected — writing to Postgres in addition to JSON")

    all_quotes = read_json(ASSET_DIR / "quotes.json", {})
    all_fundamentals = read_json(ASSET_DIR / "fundamentals.json", {})
    all_news = []
    fundamentals_done = 0
    fundamentals_attempted = 0
    news_done = 0

    batches = list(chunked(ALL_TICKERS, BATCH_SIZE))
    for i, batch in enumerate(batches, start=1):
        print(f"Batch {i}/{len(batches)} ({len(batch)} tickers)...")

        quotes, history = fetch_batch_quotes_and_history(batch)
        all_quotes.update(quotes)

        # Quotes FIRST — upsert_quote() registers the ticker in the shared
        # `tickers` table, which upsert_history_row() depends on via FK.
        if conn:
            for q in quotes.values():
                dbmod.upsert_quote(conn, q)

        for ticker, hist in history.items():
            save_json(os.path.join(HISTORY_DIR, f"{ticker}.json"), hist)
            if conn:
                for row in hist["data"]:
                    dbmod.upsert_history_row(conn, ticker, row)

        # Fundamentals + news: capped subset only, spread across batches
        for ticker in batch:
            if fundamentals_attempted < FUNDAMENTALS_LIMIT:
                fundamentals_attempted += 1
                fund = fetch_fundamentals(ticker)
                if fund:
                    all_fundamentals[ticker] = fund
                    fundamentals_done += 1
                    if conn:
                        dbmod.upsert_fundamentals(conn, fund)

            if news_done < NEWS_TICKER_LIMIT:
                news = fetch_news(ticker, limit=NEWS_LIMIT_PER_TICKER)
                all_news.extend(news)
                news_done += 1

        save_json(os.path.join(DATA_DIR, 'quotes.json'), all_quotes)
        save_json(os.path.join(DATA_DIR, 'fundamentals.json'), all_fundamentals)
        save_json(os.path.join(DATA_DIR, 'news.json'), merge_news_with_existing(all_news))
        print(f"  batch done — {len(all_quotes)} quotes, {fundamentals_done} fundamentals, "
              f"{news_done} tickers' news so far")
        time.sleep(BATCH_PAUSE_SECONDS)

    all_news.sort(key=lambda a: a.get("published_at") or "", reverse=True)

    # Keep the full week, deduped by link — merge with anything already
    # saved from earlier runs so re-running doesn't lose earlier days.
    all_news = merge_news_with_existing(all_news)

    if conn:
        for article in all_news:
            dbmod.insert_news_article(conn, article)  # links article to its related_tickers automatically
        deleted_hist = dbmod.cleanup_old_history(conn, days=30)
        deleted_news = dbmod.cleanup_old_news(conn, days=NEWS_RETENTION_DAYS)
        print(f"  [db] cleanup: removed {deleted_hist} old price_history rows, "
              f"{deleted_news} news articles past {NEWS_RETENTION_DAYS} days")
        conn.close()

    save_json(os.path.join(DATA_DIR, "quotes.json"), all_quotes)
    save_json(os.path.join(DATA_DIR, "fundamentals.json"), all_fundamentals)
    save_json(os.path.join(DATA_DIR, "news.json"), all_news)

    print(f"\nSummary: {len(all_quotes)} quotes, {len(all_fundamentals)} fundamentals "
          f"(capped subset), {len(all_news)} news articles "
          f"(rolling {NEWS_RETENTION_DAYS}-day window), "
          f"{len(all_quotes)} history files."
          + ("  [+ written to Postgres]" if DB_ENABLED else ""))
    print("Done. Files written to ./data/")


def merge_news_with_existing(new_articles):
    """
    Loads news.json from the previous run (if any), merges in the new
    articles, dedupes by link, drops anything older than the retention
    window, and returns the combined week's worth of news.
    """
    news_path = os.path.join(DATA_DIR, "news.json")
    existing = []
    if os.path.exists(news_path):
        try:
            with open(news_path, "r", encoding="utf-8") as f:
                existing = json.load(f)
        except Exception:
            existing = []

    combined = {a.get("link") or a.get("title"): a for a in merge_news(existing, new_articles)}

    cutoff = datetime.now(timezone.utc) - timedelta(days=NEWS_RETENTION_DAYS)
    result = []
    for a in combined.values():
        pub = parse_published_at(a.get("published_at"))
        if pub is None or pub >= cutoff:
            result.append(a)

    result.sort(key=lambda a: a.get("published_at") or "", reverse=True)
    return result


if __name__ == "__main__":
    main()
