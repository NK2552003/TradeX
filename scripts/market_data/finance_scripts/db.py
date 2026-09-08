"""
Postgres storage layer for the finance data fetcher.

Design (see schema.sql for full rationale):
  - stock_quotes is TRUNCATED before every run, then refilled — always
    holds exactly the latest snapshot, never accumulates.
  - news_articles is a ROLLING 7-DAY WINDOW (not truncated) — articles are
    upserted (deduped by link), and a daily cleanup deletes anything older
    than NEWS_RETENTION_DAYS. This keeps the full week of detailed news
    available, while still bounding storage over time.
  - stock_fundamentals is upserted per ticker (rarely needs truncating —
    one row per ticker regardless of how many times you run this).
  - stock_price_history is append-only per (ticker, date), with a daily
    cleanup that deletes rows older than 30 days — needed so charts still
    have a trend to show, capped so it never grows unbounded.

Usage from fetch_finance_data.py:
    from db import get_connection, init_schema, reset_daily_tables, \
        upsert_quote, upsert_fundamentals, upsert_history_row, \
        insert_news, cleanup_old_history, cleanup_old_news

Requires:
    pip install psycopg2-binary --break-system-packages

Set DATABASE_URL in your environment or a .env file, e.g.:
    DATABASE_URL=postgresql://postgres:devpass@localhost:5432/financeapp
"""

import json
import os
from datetime import date, timedelta

import psycopg2
import psycopg2.extras

SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "schema.sql")


def get_connection():
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        raise RuntimeError(
            "DATABASE_URL not set. Example:\n"
            "  export DATABASE_URL=postgresql://postgres:devpass@localhost:5432/financeapp"
        )
    return psycopg2.connect(db_url)


def init_schema(conn):
    """Creates all tables/indexes if they don't already exist. Safe to call every run."""
    with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
        sql = f.read()
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()
    print("  [db] schema ensured")


def reset_daily_tables(conn):
    """
    Wipes ONLY stock_quotes — this run's prices become the complete, sole
    record for 'now'. news_articles is intentionally NOT truncated here;
    it's a rolling 7-day window maintained by cleanup_old_news() instead,
    since a single day's news isn't enough for a week-long feed.
    """
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE stock_quotes;")
    conn.commit()
    print("  [db] stock_quotes truncated for fresh write")


def upsert_quote(conn, q):
    if not q:
        return
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO stock_quotes
                (ticker, market, exchange, currency, price, previous_close,
                 day_high, day_low, volume, change_pct, updated_at)
            VALUES (%(ticker)s, %(market)s, %(exchange)s, %(currency)s, %(price)s,
                    %(previous_close)s, %(day_high)s, %(day_low)s, %(volume)s,
                    %(change_pct)s, %(updated_at)s)
            ON CONFLICT (ticker) DO UPDATE SET
                price = EXCLUDED.price,
                previous_close = EXCLUDED.previous_close,
                day_high = EXCLUDED.day_high,
                day_low = EXCLUDED.day_low,
                volume = EXCLUDED.volume,
                change_pct = EXCLUDED.change_pct,
                updated_at = EXCLUDED.updated_at;
            """,
            q,
        )
    conn.commit()


def upsert_fundamentals(conn, f):
    if not f:
        return
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO stock_fundamentals
                (ticker, market, exchange, currency, name, market_cap, pe_ratio,
                 sector, industry, fifty_two_week_high, fifty_two_week_low,
                 dividend_yield, updated_at)
            VALUES (%(ticker)s, %(market)s, %(exchange)s, %(currency)s, %(name)s,
                    %(market_cap)s, %(pe_ratio)s, %(sector)s, %(industry)s,
                    %(fifty_two_week_high)s, %(fifty_two_week_low)s,
                    %(dividend_yield)s, %(updated_at)s)
            ON CONFLICT (ticker) DO UPDATE SET
                name = EXCLUDED.name,
                market_cap = EXCLUDED.market_cap,
                pe_ratio = EXCLUDED.pe_ratio,
                sector = EXCLUDED.sector,
                industry = EXCLUDED.industry,
                fifty_two_week_high = EXCLUDED.fifty_two_week_high,
                fifty_two_week_low = EXCLUDED.fifty_two_week_low,
                dividend_yield = EXCLUDED.dividend_yield,
                updated_at = EXCLUDED.updated_at;
            """,
            f,
        )
    conn.commit()


def upsert_history_row(conn, ticker, market, currency, row):
    """One OHLCV row for one ticker for one calendar day."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO stock_price_history
                (ticker, market, currency, date, open, high, low, close, volume)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (ticker, date) DO UPDATE SET
                open = EXCLUDED.open,
                high = EXCLUDED.high,
                low = EXCLUDED.low,
                close = EXCLUDED.close,
                volume = EXCLUDED.volume,
                recorded_at = NOW();
            """,
            (
                ticker,
                market,
                currency,
                row["date"][:10],  # date part only
                row["open"],
                row["high"],
                row["low"],
                row["close"],
                row["volume"],
            ),
        )
    conn.commit()


def insert_news(conn, article):
    """
    Upserts by link (unique constraint in schema.sql) so re-fetching the
    same article across runs updates it in place instead of duplicating —
    this is what lets news_articles safely accumulate a full week.
    """
    related = article.get("related_tickers")
    related_json = json.dumps(related) if related is not None else None

    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO news_articles
                (ticker, market, title, summary, link, publisher,
                 thumbnail_url, related_tickers, content_type, published_at)
            VALUES (%(ticker)s, %(market)s, %(title)s, %(summary)s, %(link)s,
                    %(publisher)s, %(thumbnail_url)s, %(related_tickers)s,
                    %(content_type)s, %(published_at)s)
            ON CONFLICT (link) DO UPDATE SET
                title = EXCLUDED.title,
                summary = EXCLUDED.summary,
                publisher = EXCLUDED.publisher,
                thumbnail_url = EXCLUDED.thumbnail_url,
                related_tickers = EXCLUDED.related_tickers,
                content_type = EXCLUDED.content_type,
                published_at = EXCLUDED.published_at,
                fetched_at = NOW();
            """,
            {**article, "related_tickers": related_json},
        )
    conn.commit()


def cleanup_old_history(conn, days=30):
    """Deletes price history older than N days — keeps the table bounded."""
    cutoff = date.today() - timedelta(days=days)
    with conn.cursor() as cur:
        cur.execute("DELETE FROM stock_price_history WHERE date < %s;", (cutoff,))
        deleted = cur.rowcount
    conn.commit()
    print(f"  [db] cleanup: removed {deleted} price_history rows older than {days} days")


def cleanup_old_news(conn, days=7):
    """Deletes news older than N days — keeps the rolling window bounded."""
    with conn.cursor() as cur:
        cur.execute(
            "DELETE FROM news_articles WHERE published_at < NOW() - (%s || ' days')::interval;",
            (days,),
        )
        deleted = cur.rowcount
    conn.commit()
    print(f"  [db] cleanup: removed {deleted} news_articles older than {days} days")
