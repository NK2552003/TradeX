"""
Shared Postgres storage layer — used by ALL FOUR kits (Core, Screeners,
Stock Detail, News). Every kit writes into the same tables via the same
`tickers` master registry, so data from all four kits is properly linked
by foreign key instead of living in four disconnected sets of JSON files.
"""

import json
import os
from datetime import date, timedelta

try:
    import psycopg2
    import psycopg2.extras
    PSYCOPG2_AVAILABLE = True
except ImportError:
    PSYCOPG2_AVAILABLE = False

SCHEMA_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "database", "schema.sql"))
if not os.path.exists(SCHEMA_PATH):
    SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "schema.sql")


def get_connection():
    if not PSYCOPG2_AVAILABLE:
        raise RuntimeError("psycopg2-binary package not installed.")
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        raise RuntimeError(
            "DATABASE_URL not set. Example:\n"
            "  export DATABASE_URL=postgresql://postgres:devpass@localhost:5432/financeapp"
        )
    return psycopg2.connect(db_url)


def init_schema(conn):
    """Creates all tables/indexes if they don't exist."""
    with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
        sql = f.read()
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()


def upsert_ticker(conn, ticker, market=None, exchange=None, currency=None, asset_type=None, name=None):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO tickers (ticker, market, exchange, currency, asset_type, name, last_seen_at)
            VALUES (%s, %s, %s, %s, %s, %s, NOW())
            ON CONFLICT (ticker) DO UPDATE SET
                market = COALESCE(EXCLUDED.market, tickers.market),
                exchange = COALESCE(EXCLUDED.exchange, tickers.exchange),
                currency = COALESCE(EXCLUDED.currency, tickers.currency),
                asset_type = COALESCE(EXCLUDED.asset_type, tickers.asset_type),
                name = COALESCE(EXCLUDED.name, tickers.name),
                last_seen_at = NOW();
            """,
            (ticker, market, exchange, currency, asset_type, name),
        )
    conn.commit()


def reset_quotes(conn):
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE stock_quotes;")
    conn.commit()


def upsert_quote(conn, q):
    if not q:
        return
    upsert_ticker(conn, q["ticker"], market=q.get("market"), exchange=q.get("exchange"), currency=q.get("currency"))
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO stock_quotes
                (ticker, price, previous_close, day_high, day_low, volume, change_pct, updated_at)
            VALUES (%(ticker)s, %(price)s, %(previous_close)s, %(day_high)s, %(day_low)s,
                    %(volume)s, %(change_pct)s, %(updated_at)s)
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
    upsert_ticker(conn, f["ticker"], market=f.get("market"), exchange=f.get("exchange"),
                  currency=f.get("currency"), name=f.get("name"))
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO stock_fundamentals
                (ticker, market_cap, pe_ratio, forward_pe, peg_ratio, eps, sector, industry,
                 fifty_two_week_high, fifty_two_week_low, fifty_day_average, two_hundred_day_average,
                 dividend_yield, beta, avg_volume, shares_outstanding, updated_at)
            VALUES (%(ticker)s, %(market_cap)s, %(pe_ratio)s, %(forward_pe)s, %(peg_ratio)s, %(eps)s,
                    %(sector)s, %(industry)s, %(fifty_two_week_high)s, %(fifty_two_week_low)s,
                    %(fifty_day_average)s, %(two_hundred_day_average)s, %(dividend_yield)s, %(beta)s,
                    %(avg_volume)s, %(shares_outstanding)s, %(updated_at)s)
            ON CONFLICT (ticker) DO UPDATE SET
                market_cap = EXCLUDED.market_cap,
                pe_ratio = EXCLUDED.pe_ratio,
                forward_pe = EXCLUDED.forward_pe,
                peg_ratio = EXCLUDED.peg_ratio,
                eps = EXCLUDED.eps,
                sector = EXCLUDED.sector,
                industry = EXCLUDED.industry,
                fifty_two_week_high = EXCLUDED.fifty_two_week_high,
                fifty_two_week_low = EXCLUDED.fifty_two_week_low,
                fifty_day_average = EXCLUDED.fifty_day_average,
                two_hundred_day_average = EXCLUDED.two_hundred_day_average,
                dividend_yield = EXCLUDED.dividend_yield,
                beta = EXCLUDED.beta,
                avg_volume = EXCLUDED.avg_volume,
                shares_outstanding = EXCLUDED.shares_outstanding,
                updated_at = EXCLUDED.updated_at;
            """,
            {**f, **{k: f.get(k) for k in [
                "forward_pe", "peg_ratio", "eps", "fifty_day_average",
                "two_hundred_day_average", "beta", "avg_volume", "shares_outstanding"
            ] if k not in f}},
        )
    conn.commit()


def upsert_history_row(conn, ticker, row):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO stock_price_history (ticker, date, open, high, low, close, volume)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (ticker, date) DO UPDATE SET
                open = EXCLUDED.open, high = EXCLUDED.high, low = EXCLUDED.low,
                close = EXCLUDED.close, volume = EXCLUDED.volume, recorded_at = NOW();
            """,
            (ticker, row["date"][:10], row["open"], row["high"], row["low"], row["close"], row["volume"]),
        )
    conn.commit()


def cleanup_old_history(conn, days=30):
    cutoff = date.today() - timedelta(days=days)
    with conn.cursor() as cur:
        cur.execute("DELETE FROM stock_price_history WHERE date < %s;", (cutoff,))
        deleted = cur.rowcount
    conn.commit()
    return deleted


def insert_news_article(conn, article, topic_names=None):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO news_articles (title, summary, link, publisher, thumbnail_url, content_type, published_at)
            VALUES (%(title)s, %(summary)s, %(link)s, %(publisher)s, %(thumbnail_url)s, %(content_type)s, %(published_at)s)
            ON CONFLICT (link) DO UPDATE SET
                title = EXCLUDED.title, summary = EXCLUDED.summary, publisher = EXCLUDED.publisher,
                thumbnail_url = EXCLUDED.thumbnail_url, content_type = EXCLUDED.content_type,
                published_at = EXCLUDED.published_at, fetched_at = NOW()
            RETURNING id;
            """,
            article,
        )
        article_id = cur.fetchone()[0]

        for ticker in article.get("related_tickers") or []:
            upsert_ticker(conn, ticker)
            cur.execute(
                "INSERT INTO news_article_tickers (article_id, ticker) VALUES (%s, %s) "
                "ON CONFLICT DO NOTHING;",
                (article_id, ticker),
            )

        for topic_name in topic_names or []:
            cur.execute(
                "INSERT INTO news_topics (name) VALUES (%s) ON CONFLICT (name) DO NOTHING RETURNING id;",
                (topic_name,),
            )
            row = cur.fetchone()
            if row is None:
                cur.execute("SELECT id FROM news_topics WHERE name = %s;", (topic_name,))
                row = cur.fetchone()
            topic_id = row[0]
            cur.execute(
                "INSERT INTO news_article_topics (article_id, topic_id) VALUES (%s, %s) "
                "ON CONFLICT DO NOTHING;",
                (article_id, topic_id),
            )
    conn.commit()
    return article_id


def cleanup_old_news(conn, days=7):
    with conn.cursor() as cur:
        cur.execute(
            "DELETE FROM news_articles WHERE published_at < NOW() - (%s || ' days')::interval;",
            (days,),
        )
        deleted = cur.rowcount
    conn.commit()
    return deleted


def get_or_create_category(conn, name, category_type):
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO screener_categories (name, category_type) VALUES (%s, %s) "
            "ON CONFLICT (name) DO UPDATE SET category_type = EXCLUDED.category_type "
            "RETURNING id;",
            (name, category_type),
        )
        category_id = cur.fetchone()[0]
    conn.commit()
    return category_id


def reset_category_results(conn, category_id):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM screener_results WHERE category_id = %s;", (category_id,))
    conn.commit()


def insert_screener_result(conn, category_id, ticker, rank, price=None, change_pct=None, extra_data=None):
    upsert_ticker(conn, ticker)
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO screener_results (category_id, ticker, rank, price, change_pct, extra_data)
            VALUES (%s, %s, %s, %s, %s, %s);
            """,
            (category_id, ticker, rank, price, change_pct, json.dumps(extra_data) if extra_data else None),
        )
    conn.commit()


def upsert_index_metadata(conn, ticker, continent):
    upsert_ticker(conn, ticker, asset_type="index")
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO index_metadata (ticker, continent) VALUES (%s, %s)
            ON CONFLICT (ticker) DO UPDATE SET continent = EXCLUDED.continent;
            """,
            (ticker, continent),
        )
    conn.commit()


def upsert_sector_metadata(conn, ticker, sector_name):
    upsert_ticker(conn, ticker, asset_type="etf")
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO sector_metadata (ticker, sector_name) VALUES (%s, %s)
            ON CONFLICT (ticker) DO UPDATE SET sector_name = EXCLUDED.sector_name;
            """,
            (ticker, sector_name),
        )
    conn.commit()


def replace_options(conn, ticker, expirations_data):
    upsert_ticker(conn, ticker)
    with conn.cursor() as cur:
        cur.execute("DELETE FROM options_expirations WHERE ticker = %s;", (ticker,))
        for exp_date, chains in expirations_data.items():
            cur.execute(
                "INSERT INTO options_expirations (ticker, expiration_date) VALUES (%s, %s) RETURNING id;",
                (ticker, exp_date),
            )
            expiration_id = cur.fetchone()[0]
            for contract_type, contracts in (("call", chains.get("calls", [])), ("put", chains.get("puts", []))):
                for c in contracts:
                    cur.execute(
                        """
                        INSERT INTO options_contracts
                            (expiration_id, contract_type, strike, last_price, bid, ask,
                             volume, open_interest, implied_volatility, in_the_money, contract_symbol)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
                        """,
                        (
                            expiration_id, contract_type,
                            c.get("strike"), c.get("lastPrice"), c.get("bid"), c.get("ask"),
                            c.get("volume"), c.get("openInterest"), c.get("impliedVolatility"),
                            c.get("inTheMoney"), c.get("contractSymbol"),
                        ),
                    )
    conn.commit()


def replace_dividends_and_splits(conn, ticker, dividends, splits):
    upsert_ticker(conn, ticker)
    with conn.cursor() as cur:
        for d in dividends:
            cur.execute(
                """
                INSERT INTO dividends (ticker, ex_date, amount) VALUES (%s, %s, %s)
                ON CONFLICT (ticker, ex_date) DO UPDATE SET amount = EXCLUDED.amount;
                """,
                (ticker, d["date"][:10], d["amount"]),
            )
        for s in splits:
            cur.execute(
                """
                INSERT INTO stock_splits (ticker, split_date, ratio) VALUES (%s, %s, %s)
                ON CONFLICT (ticker, split_date) DO UPDATE SET ratio = EXCLUDED.ratio;
                """,
                (ticker, s["date"][:10], s["ratio"]),
            )
    conn.commit()


def replace_holders(conn, ticker, major_holders, institutional_holders):
    upsert_ticker(conn, ticker)
    with conn.cursor() as cur:
        cur.execute("DELETE FROM holders WHERE ticker = %s;", (ticker,))
        for h in major_holders:
            cur.execute(
                """
                INSERT INTO holders (ticker, holder_type, holder_name, pct_out)
                VALUES (%s, 'major', %s, %s);
                """,
                (ticker, str(h.get("Value") or h.get("Breakdown") or h), None),
            )
        for h in institutional_holders:
            cur.execute(
                """
                INSERT INTO holders (ticker, holder_type, holder_name, shares, date_reported, pct_out, value)
                VALUES (%s, 'institutional', %s, %s, %s, %s, %s);
                """,
                (
                    ticker, h.get("Holder"), h.get("Shares"), h.get("Date Reported"),
                    h.get("pctHeld") or h.get("% Out"), h.get("Value"),
                ),
            )
    conn.commit()


def insert_recommendation_snapshot(conn, ticker, rec):
    upsert_ticker(conn, ticker)
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO analyst_recommendations (ticker, period, strong_buy, buy, hold, sell, strong_sell)
            VALUES (%s, %s, %s, %s, %s, %s, %s);
            """,
            (
                ticker, rec.get("period"), rec.get("strongBuy"), rec.get("buy"),
                rec.get("hold"), rec.get("sell"), rec.get("strongSell"),
            ),
        )
    conn.commit()
