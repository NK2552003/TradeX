#!/usr/bin/env python3
"""
AlphaJournal (TradeX) — Automated Market Intelligence & Database Sync Pipeline

Executes in CI/CD (GitHub Actions) and production cron workers.
1. Cleans the Supabase Postgres database (stale quotes, old history > 30d, old news > 7d, stale screeners).
2. Fetches live market quotes, OHLCV history, fundamentals, and complete company details
   for the top 200 prominent tickers (100 US leaders + 100 India/NSE leaders).
3. Stores data directly in Supabase Postgres:
   - tickers
   - stock_quotes
   - stock_fundamentals
   - stock_price_history
   - stock_details (complete company overview JSON)
   - screener_categories, screener_results, market_screener_snapshots
   - news_articles, news_article_tickers
"""

import json
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta, timezone

# ---------------------------------------------------------------------------
# 200 Curated Prominent Tickers (100 Top US + 100 Top India/NSE)
# ---------------------------------------------------------------------------

US_TICKERS = [
    # Magnificent Seven & Mega-Cap Tech
    "AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA",
    # Semiconductors & Hardware
    "AMD", "INTC", "AVGO", "QCOM", "TXN", "ARM", "MU", "AMAT", "LRCX", "KLAC",
    # Enterprise Software, Cloud & AI
    "CRM", "ORCL", "ADBE", "NOW", "PLTR", "SNOW", "PANW", "CRWD", "WDAY", "INTU",
    # Consumer Tech, Streaming & FinTech
    "NFLX", "UBER", "ABNB", "PYPL", "SQ", "COIN", "SHOP", "SPOT",
    # Financials & Banking
    "JPM", "BAC", "WFC", "MS", "GS", "BLK", "C", "AXP", "V", "MA",
    # Healthcare & Pharma
    "LLY", "UNH", "JNJ", "PFE", "MRK", "ABBV", "TMO", "DHR", "ISRG", "BMY", "AMGN", "GILD",
    # Retail & Consumer Goods
    "WMT", "COST", "TGT", "HD", "LOW", "MCD", "SBUX", "NKE", "KO", "PEP", "PG", "PM", "CL",
    # Industrials & Aerospace
    "GE", "CAT", "DE", "BA", "LMT", "RTX", "HON", "UNP", "UPS", "FDX",
    # Energy & Utilities
    "XOM", "CVX", "COP", "SLB", "EOG", "NEE", "DUK", "SO",
    # Telecom & Media
    "T", "VZ", "DIS", "CMCSA",
    # Broad Market & Sector ETFs
    "SPY", "QQQ", "DIA", "IWM", "VOO", "VTI", "XLK", "XLF", "XLE", "XLV", "SMH",
    # Major Crypto Pairs
    "BTC-USD", "ETH-USD", "SOL-USD", "BNB-USD", "XRP-USD",
]

IN_TICKERS = [
    # Benchmark Indices
    "^NSEI", "^NSEBANK", "^BSESN",
    # Nifty 50 Heavyweights
    "RELIANCE.NS", "TCS.NS", "HDFCBANK.NS", "INFY.NS", "ICICIBANK.NS",
    "BHARTIARTL.NS", "SBIN.NS", "ITC.NS", "LT.NS", "HINDUNILVR.NS",
    "BAJFINANCE.NS", "KOTAKBANK.NS", "AXISBANK.NS", "HCLTECH.NS", "MARUTI.NS",
    "SUNPHARMA.NS", "TATAMOTORS.NS", "NTPC.NS", "ONGC.NS", "TITAN.NS",
    "POWERGRID.NS", "ADANIENT.NS", "ADANIPORTS.NS", "COALINDIA.NS", "TATASTEEL.NS",
    "BAJAJFINSV.NS", "ASIANPAINT.NS", "M&M.NS", "ULTRACEMCO.NS", "WIPRO.NS",
    "NESTLEIND.NS", "JSWSTEEL.NS", "TECHM.NS", "GRASIM.NS", "LTIM.NS",
    "SBILIFE.NS", "HDFCLIFE.NS", "DRREDDY.NS", "CIPLA.NS", "BRITANNIA.NS",
    "HEROMOTOCO.NS", "EICHERMOT.NS", "DIVISLAB.NS", "HINDALCO.NS", "APOLLOHOSP.NS",
    "BPCL.NS", "TRENT.NS", "BEL.NS", "SHREECEM.NS", "INDUSINDBK.NS",
    # Next 50 & High-Conviction Midcaps
    "ZOMATO.NS", "JIOFIN.NS", "VBL.NS", "HAL.NS", "DLF.NS",
    "CHOLAFIN.NS", "SIEMENS.NS", "ABB.NS", "PFC.NS", "RECLTD.NS",
    "GAIL.NS", "IOC.NS", "TATAPOWER.NS", "POLYCAB.NS", "BHEL.NS",
    "IRFC.NS", "RVNL.NS", "SUZLON.NS", "IDEA.NS", "YESBANK.NS",
    "IDFCFIRSTB.NS", "FEDERALBNK.NS", "PNB.NS", "BANKBARODA.NS", "CANBK.NS",
    "UNIONBANK.NS", "AUROPHARMA.NS", "LUPIN.NS", "TORNTPHARM.NS", "MUTHOOTFIN.NS",
    "SHRIRAMFIN.NS", "TATACOMM.NS", "PERSISTENT.NS", "COFORGE.NS", "KPITTECH.NS",
    "DIXON.NS", "CGPOWER.NS", "MAXHEALTH.NS", "MANKIND.NS", "BOSCHLTD.NS",
    "PIDILITIND.NS", "HAVELLS.NS", "DABUR.NS", "GODREJCP.NS", "MARICO.NS",
    "COLPAL.NS", "BERGEPAINT.NS", "MOTHERSON.NS", "BALKRISIND.NS", "INDIGO.NS",
]

TARGET_TICKERS = list(dict.fromkeys(US_TICKERS + IN_TICKERS))[:200]

# ---------------------------------------------------------------------------
# Configuration & Database Connection
# ---------------------------------------------------------------------------

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = (
    os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or
    os.environ.get("SUPABASE_ANON_KEY") or
    ""
).strip()
DATABASE_URL = os.environ.get("DATABASE_URL", "").strip()

if not SUPABASE_URL and not DATABASE_URL:
    print("[pipeline] Error: SUPABASE_URL or DATABASE_URL must be set.")
    sys.exit(1)


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


# ---------------------------------------------------------------------------
# Supabase PostgREST Client (zero external dependencies required)
# ---------------------------------------------------------------------------

def supabase_request(method, path, body=None, prefer=None):
    if not SUPABASE_URL:
        return None
    url = f"{SUPABASE_URL}/rest/v1/{path.lstrip('/')}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            content = resp.read()
            if content:
                try:
                    return json.loads(content.decode("utf-8"))
                except Exception:
                    return None
            return None
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8", errors="replace")
        print(f"  [supabase] HTTP {e.code} on {method} {path}: {err_msg[:200]}")
        return None
    except Exception as e:
        print(f"  [supabase] Request failed on {method} {path}: {e}")
        return None


def supabase_upsert(table, rows, on_conflict=None, chunk_size=100):
    if not rows:
        return 0
    total = 0
    query = f"?on_conflict={urllib.parse.quote(on_conflict)}" if on_conflict else ""
    prefer = "resolution=merge-duplicates,return=minimal"
    for i in range(0, len(rows), chunk_size):
        chunk = rows[i:i + chunk_size]
        res = supabase_request("POST", f"{table}{query}", body=chunk, prefer=prefer)
        total += len(chunk)
    return total


def supabase_delete(path):
    return supabase_request("DELETE", path, prefer="return=minimal")


# ---------------------------------------------------------------------------
# Database Cleaning
# ---------------------------------------------------------------------------

def clean_database():
    """Purges stale data across quotes, history (>30d), and news (>7d)."""
    print("[pipeline] Step 1: Cleaning stale database records...")
    
    # 1. Clean old price history (> 30 days old)
    cutoff_history = (date.today() - timedelta(days=30)).isoformat()
    supabase_delete(f"stock_price_history?date=lt.{cutoff_history}")
    print(f"  [clean] Cleared price history older than {cutoff_history}")

    # 2. Clean old news articles (> 7 days old)
    cutoff_news = (datetime.now(timezone.utc) - timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ")
    supabase_delete(f"news_articles?published_at=lt.{cutoff_news}")
    print(f"  [clean] Cleared news articles older than {cutoff_news}")

    # 3. Clean screener results to allow fresh ranking
    supabase_delete("screener_results?id=gt.0")
    print("  [clean] Reset screener results table for fresh daily ranks")


# ---------------------------------------------------------------------------
# Live Yahoo Finance Fetcher via Direct Chart API
# ---------------------------------------------------------------------------

def fetch_yahoo_chart(symbol, range_str="1mo", interval="1d"):
    """Fetches OHLCV chart bars and quote metadata from Yahoo Finance v8 API."""
    encoded = urllib.parse.quote(symbol)
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{encoded}?range={range_str}&interval={interval}"
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("chart", {}).get("result", [None])[0]
    except Exception as e:
        return None


def fetch_yahoo_quote_summary(symbol):
    """Fetches company profile & key statistics from Yahoo Finance summary API."""
    encoded = urllib.parse.quote(symbol)
    modules = "summaryProfile,summaryDetail,financialData,defaultKeyStatistics,assetProfile"
    url = f"https://query1.finance.yahoo.com/v10/finance/quoteSummary/{encoded}?modules={modules}"
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("quoteSummary", {}).get("result", [None])[0]
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Sync Tickers, Quotes, Fundamentals, and Whole Details
# ---------------------------------------------------------------------------

def sync_market_and_company_details(symbols):
    print(f"[pipeline] Step 2: Fetching & storing whole details for {len(symbols)} tickers...")

    ticker_rows = []
    quote_rows = []
    fundamental_rows = []
    history_rows = []
    detail_rows = []

    for i, symbol in enumerate(symbols):
        is_in = symbol.endswith(".NS") or symbol.endswith(".BO") or symbol in ("^NSEI", "^NSEBANK", "^BSESN")
        is_crypto = symbol.endswith("-USD")
        market = "IN" if is_in else ("CRYPTO" if is_crypto else "US")
        exchange = "NSE" if is_in else ("CRYPTO" if is_crypto else "NASDAQ")
        currency = "INR" if is_in else "USD"
        asset_type = "INDEX" if symbol.startswith("^") else ("CRYPTO" if is_crypto else "EQUITY")

        chart = fetch_yahoo_chart(symbol, range_str="1mo", interval="1d")
        summary_raw = fetch_yahoo_quote_summary(symbol) or {}

        meta = chart.get("meta", {}) if chart else {}
        price = meta.get("regularMarketPrice") or 0.0
        prev_close = meta.get("chartPreviousClose") or meta.get("previousClose") or price
        day_high = meta.get("regularMarketDayHigh") or price
        day_low = meta.get("regularMarketDayLow") or price
        volume = meta.get("regularMarketVolume") or 0
        change_pct = round(((price - prev_close) / prev_close) * 100, 2) if prev_close > 0 else 0.0

        profile = summary_raw.get("summaryProfile", {})
        detail = summary_raw.get("summaryDetail", {})
        key_stats = summary_raw.get("defaultKeyStatistics", {})
        fin_data = summary_raw.get("financialData", {})

        company_name = meta.get("longName") or meta.get("shortName") or symbol
        sector = profile.get("sector") or None
        industry = profile.get("industry") or None
        market_cap = detail.get("marketCap", {}).get("raw") or None
        pe_ratio = detail.get("trailingPE", {}).get("raw") or None
        forward_pe = detail.get("forwardPE", {}).get("raw") or None
        peg_ratio = key_stats.get("pegRatio", {}).get("raw") or None
        eps = key_stats.get("trailingEps", {}).get("raw") or None
        div_yield = detail.get("dividendYield", {}).get("raw") or None
        beta = key_stats.get("beta", {}).get("raw") or None
        high_52 = detail.get("fiftyTwoWeekHigh", {}).get("raw") or day_high
        low_52 = detail.get("fiftyTwoWeekLow", {}).get("raw") or day_low

        ticker_rows.append({
            "ticker": symbol,
            "market": market,
            "exchange": exchange,
            "currency": currency,
            "asset_type": asset_type,
            "name": company_name,
            "last_seen_at": now_iso(),
        })

        if price > 0:
            quote_rows.append({
                "ticker": symbol,
                "price": price,
                "previous_close": prev_close,
                "day_high": day_high,
                "day_low": day_low,
                "volume": int(volume),
                "change_pct": change_pct,
                "updated_at": now_iso(),
            })

            fundamental_rows.append({
                "ticker": symbol,
                "market_cap": market_cap,
                "pe_ratio": pe_ratio,
                "forward_pe": forward_pe,
                "peg_ratio": peg_ratio,
                "eps": eps,
                "sector": sector,
                "industry": industry,
                "fifty_two_week_high": high_52,
                "fifty_two_week_low": low_52,
                "dividend_yield": div_yield,
                "beta": beta,
                "avg_volume": detail.get("averageVolume", {}).get("raw") or None,
                "shares_outstanding": key_stats.get("sharesOutstanding", {}).get("raw") or None,
                "updated_at": now_iso(),
            })

        # Process Historical Daily Bars
        indicators = chart.get("indicators", {}).get("quote", [{}])[0] if chart else {}
        timestamps = chart.get("timestamp", []) if chart else []
        opens = indicators.get("open", [])
        highs = indicators.get("high", [])
        lows = indicators.get("low", [])
        closes = indicators.get("close", [])
        volumes = indicators.get("volume", [])

        recent_bars = []
        for idx, ts in enumerate(timestamps):
            if ts and idx < len(closes) and closes[idx] is not None:
                d_str = datetime.fromtimestamp(ts, timezone.utc).strftime("%Y-%m-%d")
                b_open = opens[idx] if idx < len(opens) and opens[idx] is not None else closes[idx]
                b_high = highs[idx] if idx < len(highs) and highs[idx] is not None else closes[idx]
                b_low = lows[idx] if idx < len(lows) and lows[idx] is not None else closes[idx]
                b_close = closes[idx]
                b_vol = int(volumes[idx]) if idx < len(volumes) and volumes[idx] is not None else 0

                bar_data = {
                    "date": d_str,
                    "open": b_open,
                    "high": b_high,
                    "low": b_low,
                    "close": b_close,
                    "volume": b_vol,
                }
                recent_bars.append(bar_data)
                history_rows.append({
                    "ticker": symbol,
                    "date": d_str,
                    "open": b_open,
                    "high": b_high,
                    "low": b_low,
                    "close": b_close,
                    "volume": b_vol,
                    "recorded_at": now_iso(),
                })

        # Whole Company Detail Structured Payload
        whole_detail = {
            "ticker": symbol,
            "name": company_name,
            "summary": {
                "name": company_name,
                "sector": sector,
                "industry": industry,
                "website": profile.get("website"),
                "description": profile.get("longBusinessSummary"),
                "market_cap": market_cap,
                "pe_ratio": pe_ratio,
                "forward_pe": forward_pe,
                "peg_ratio": peg_ratio,
                "eps": eps,
                "dividend_yield": div_yield,
                "beta": beta,
                "fifty_two_week_high": high_52,
                "fifty_two_week_low": low_52,
            },
            "quote": {
                "price": price,
                "previous_close": prev_close,
                "day_high": day_high,
                "day_low": day_low,
                "volume": int(volume),
                "change_pct": change_pct,
            },
            "history": recent_bars[-30:],
            "updated_at": now_iso(),
        }

        detail_rows.append({
            "ticker": symbol,
            "detail": whole_detail,
            "fetched_at": now_iso(),
        })

        if (i + 1) % 20 == 0 or (i + 1) == len(symbols):
            print(f"  [progress] Processed {i + 1}/{len(symbols)} tickers...")
        time.sleep(0.08)  # Polite pacing

    # Batch upsert all collected datasets
    u_tickers = supabase_upsert("tickers", ticker_rows, on_conflict="ticker")
    u_quotes = supabase_upsert("stock_quotes", quote_rows, on_conflict="ticker")
    u_fund = supabase_upsert("stock_fundamentals", fundamental_rows, on_conflict="ticker")
    u_hist = supabase_upsert("stock_price_history", history_rows, on_conflict="ticker,date", chunk_size=200)
    u_detail = supabase_upsert("stock_details", detail_rows, on_conflict="ticker", chunk_size=50)

    print(f"  [saved] Tickers: {u_tickers}, Quotes: {u_quotes}, Fundamentals: {u_fund}, History: {u_hist}, Whole Details: {u_detail}")
    return quote_rows


# ---------------------------------------------------------------------------
# Market Screeners Sync
# ---------------------------------------------------------------------------

def sync_screeners(quotes):
    print("[pipeline] Step 3: Generating & syncing screeners...")
    if not quotes:
        return

    us_quotes = [q for q in quotes if not q["ticker"].endswith(".NS") and not q["ticker"].endswith("-USD") and not q["ticker"].startswith("^")]
    in_quotes = [q for q in quotes if q["ticker"].endswith(".NS")]
    crypto_quotes = [q for q in quotes if q["ticker"].endswith("-USD")]

    categories = [
        {"name": "top_gainers", "category_type": "GLOBAL", "quotes": sorted(us_quotes, key=lambda q: q["change_pct"], reverse=True)[:15]},
        {"name": "top_losers", "category_type": "GLOBAL", "quotes": sorted(us_quotes, key=lambda q: q["change_pct"])[:15]},
        {"name": "most_active", "category_type": "GLOBAL", "quotes": sorted(us_quotes, key=lambda q: q["volume"], reverse=True)[:15]},
        {"name": "india_top_gainers", "category_type": "IN", "quotes": sorted(in_quotes, key=lambda q: q["change_pct"], reverse=True)[:15]},
        {"name": "india_top_losers", "category_type": "IN", "quotes": sorted(in_quotes, key=lambda q: q["change_pct"])[:15]},
        {"name": "crypto_all", "category_type": "CRYPTO", "quotes": sorted(crypto_quotes, key=lambda q: q["volume"], reverse=True)[:10]},
    ]

    cat_rows = [{"name": c["name"], "category_type": c["category_type"]} for c in categories]
    supabase_upsert("screener_categories", cat_rows, on_conflict="name")

    db_cats = supabase_request("GET", "screener_categories?select=id,name") or []
    id_by_name = {c["name"]: c["id"] for c in db_cats if "id" in c and "name" in c}

    result_rows = []
    snapshot_rows = []

    for cat in categories:
        cat_id = id_by_name.get(cat["name"])
        if not cat_id:
            continue
        for idx, q in enumerate(cat["quotes"]):
            result_rows.append({
                "category_id": cat_id,
                "ticker": q["ticker"],
                "rank": idx + 1,
                "price": q["price"],
                "change_pct": q["change_pct"],
                "extra_data": q,
            })
        snapshot_rows.append({
            "category_id": cat_id,
            "payload": {"name": cat["name"], "category_type": cat["category_type"], "quotes": cat["quotes"]},
            "exported_at": now_iso(),
        })

    supabase_upsert("screener_results", result_rows)
    supabase_upsert("market_screener_snapshots", snapshot_rows, on_conflict="category_id")
    print(f"  [screeners] Synced {len(categories)} categories and {len(result_rows)} ranked items")


# ---------------------------------------------------------------------------
# Live News Sync
# ---------------------------------------------------------------------------

def fetch_rss_news():
    import re
    import xml.etree.ElementTree as ET

    feeds = [
        ("Economic Times", "https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms"),
        ("Moneycontrol", "https://www.moneycontrol.com/rss/MCtopnews.xml"),
        ("Yahoo Finance", "https://finance.yahoo.com/news/rssindex"),
    ]
    articles = []

    for pub, url in feeds:
        req = urllib.request.Request(url, headers={"User-Agent": "AlphaJournal/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                xml_data = resp.read()
                root = ET.fromstring(xml_data)
                for item in root.findall(".//item")[:15]:
                    title_elem = item.find("title")
                    link_elem = item.find("link")
                    desc_elem = item.find("description")
                    pub_elem = item.find("pubDate")

                    title = (title_elem.text or "").strip() if title_elem is not None else ""
                    link = (link_elem.text or "").strip() if link_elem is not None else ""
                    summary = (desc_elem.text or "").strip() if desc_elem is not None else title
                    summary = re.sub(r"<[^>]+>", "", summary).strip()

                    if title and link:
                        articles.append({
                            "title": title,
                            "summary": summary[:400],
                            "link": link,
                            "publisher": pub,
                            "thumbnail_url": None,
                            "content_type": "STORY",
                            "published_at": now_iso(),
                        })
        except Exception as e:
            print(f"  [news] RSS fetch skipped for {pub}: {e}")

    return articles


def sync_news(known_symbols):
    print("[pipeline] Step 4: Fetching & syncing live financial news...")
    articles = fetch_rss_news()
    if not articles:
        return

    supabase_upsert("news_articles", articles, on_conflict="link")

    # Link articles to mentioned tickers
    db_articles = supabase_request("GET", "news_articles?select=id,title,summary&limit=100") or []
    ticker_links = []
    symbol_set = set(known_symbols)

    for art in db_articles:
        text = f"{art.get('title', '')} {art.get('summary', '')}".upper()
        for sym in symbol_set:
            clean_sym = sym.replace(".NS", "").replace("-USD", "")
            if len(clean_sym) >= 3 and f" {clean_sym} " in f" {text} ":
                ticker_links.append({
                    "article_id": art["id"],
                    "ticker": sym,
                })

    if ticker_links:
        supabase_upsert("news_article_tickers", ticker_links, on_conflict="article_id,ticker")
        print(f"  [news] Linked {len(ticker_links)} ticker-news associations")


# ---------------------------------------------------------------------------
# Main Execution Entrypoint
# ---------------------------------------------------------------------------

def main():
    start_time = time.time()
    print("===================================================================")
    print(" AlphaJournal CI/CD Market Sync & Database Cleaning Pipeline")
    print(f" Target: Top 200 prominent tickers | Started at: {now_iso()}")
    print("===================================================================")

    clean_database()
    quotes = sync_market_and_company_details(TARGET_TICKERS)
    sync_screeners(quotes)
    sync_news(TARGET_TICKERS)

    elapsed = round(time.time() - start_time, 2)
    print("===================================================================")
    print(f" Pipeline successfully finished in {elapsed}s.")
    print("===================================================================")


if __name__ == "__main__":
    main()
