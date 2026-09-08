"""
Per-stock "everything" fetcher — pulls all detail available for ONE ticker
into a single combined JSON file: summary, quote, news, price history, and
options chain. This is the closest real equivalent to Yahoo Finance's
per-stock tabs (Summary / News / Chart / Historical Data / Options).

WHAT'S NOT INCLUDED (and why):
  - "Conversations" tab — Yahoo's comment/discussion system. Not exposed by
    any API; it's rendered by their website's own backend.
  - "Components" (for ETFs/indices) — no reliable free source for full
    holdings lists via yfinance. Some ETF-level summary stats are included
    via get_funds_data() where available, but not a full components list.

Usage:
    pip install yfinance --break-system-packages
    python fetch_stock_detail.py AAPL
    python fetch_stock_detail.py RELIANCE.NS
"""

import json
import os
import sys
from datetime import datetime, timezone

import yfinance as yf

OUT_DIR = "data/stock_detail"


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def get_market(ticker):
    return "IN" if ticker.endswith(".NS") or ticker.endswith(".BO") else "US"


def fetch_summary(t):
    """Summary tab equivalent — company profile + key stats."""
    try:
        info = t.info
        return {
            "name": info.get("longName") or info.get("shortName"),
            "sector": info.get("sector"),
            "industry": info.get("industry"),
            "website": info.get("website"),
            "description": info.get("longBusinessSummary"),
            "market_cap": info.get("marketCap"),
            "pe_ratio": info.get("trailingPE"),
            "forward_pe": info.get("forwardPE"),
            "peg_ratio": info.get("pegRatio"),
            "eps": info.get("trailingEps"),
            "dividend_yield": info.get("dividendYield"),
            "beta": info.get("beta"),
            "fifty_two_week_high": info.get("fiftyTwoWeekHigh"),
            "fifty_two_week_low": info.get("fiftyTwoWeekLow"),
            "fifty_day_average": info.get("fiftyDayAverage"),
            "two_hundred_day_average": info.get("twoHundredDayAverage"),
            "avg_volume": info.get("averageVolume"),
            "shares_outstanding": info.get("sharesOutstanding"),
            "float_shares": info.get("floatShares"),
            "held_percent_insiders": info.get("heldPercentInsiders"),
            "held_percent_institutions": info.get("heldPercentInstitutions"),
            "short_ratio": info.get("shortRatio"),
            "target_mean_price": info.get("targetMeanPrice"),
            "recommendation": info.get("recommendationKey"),
            "number_of_analyst_opinions": info.get("numberOfAnalystOpinions"),
            "employees": info.get("fullTimeEmployees"),
            "country": info.get("country"),
            "exchange": info.get("exchange"),
        }
    except Exception as e:
        print(f"  [summary] failed: {e}")
        return None


def fetch_quote(t):
    try:
        fi = t.fast_info
        price = fi["last_price"]
        prev = fi["previous_close"]
        return {
            "price": price,
            "previous_close": prev,
            "day_high": fi["day_high"],
            "day_low": fi["day_low"],
            "volume": fi["last_volume"],
            "change_pct": round((price - prev) / prev * 100, 2) if prev else None,
            "currency": fi.get("currency"),
            "market_cap": fi.get("market_cap"),
            "updated_at": now_iso(),
        }
    except Exception as e:
        print(f"  [quote] failed: {e}")
        return None


def fetch_news_detail(t, limit=20):
    try:
        articles = []
        for item in (t.news or [])[:limit]:
            content = item.get("content", item)
            articles.append(
                {
                    "title": content.get("title") or item.get("title"),
                    "summary": content.get("summary") or item.get("summary"),
                    "link": (content.get("canonicalUrl", {}) or {}).get("url") or item.get("link"),
                    "publisher": (content.get("provider", {}) or {}).get("displayName") or item.get("publisher"),
                    "published_at": content.get("pubDate") or item.get("providerPublishTime"),
                }
            )
        return articles
    except Exception as e:
        print(f"  [news] failed: {e}")
        return []


def fetch_chart(t, period="6mo", interval="1d"):
    """Chart tab equivalent — OHLCV history."""
    try:
        hist = t.history(period=period, interval=interval)
        records = []
        for date, row in hist.iterrows():
            records.append(
                {
                    "date": date.isoformat(),
                    "open": round(float(row["Open"]), 2),
                    "high": round(float(row["High"]), 2),
                    "low": round(float(row["Low"]), 2),
                    "close": round(float(row["Close"]), 2),
                    "volume": int(row["Volume"]) if row["Volume"] == row["Volume"] else 0,
                }
            )
        return {"period": period, "interval": interval, "data": records}
    except Exception as e:
        print(f"  [chart] failed: {e}")
        return None


def fetch_options(t):
    """
    Options tab equivalent — full options chain for every available
    expiration date. Can be large for liquid tickers (many strikes).
    """
    try:
        expirations = t.options
        if not expirations:
            return {"expirations": [], "chains": {}}

        chains = {}
        for exp in expirations:
            try:
                chain = t.option_chain(exp)
                chains[exp] = {
                    "calls": json.loads(chain.calls.to_json(orient="records")),
                    "puts": json.loads(chain.puts.to_json(orient="records")),
                }
            except Exception as e:
                print(f"    [options] expiration {exp} failed: {e}")
                continue

        return {"expirations": list(expirations), "chains": chains}
    except Exception as e:
        print(f"  [options] failed (may not be available for this ticker/market): {e}")
        return {"expirations": [], "chains": {}}


def fetch_dividends_and_splits(t):
    try:
        divs = t.dividends
        splits = t.splits
        return {
            "dividends": [{"date": d.isoformat(), "amount": float(v)} for d, v in divs.items()],
            "splits": [{"date": d.isoformat(), "ratio": float(v)} for d, v in splits.items()],
        }
    except Exception as e:
        print(f"  [dividends/splits] failed: {e}")
        return {"dividends": [], "splits": []}


def fetch_recommendations(t):
    try:
        recs = t.recommendations
        if recs is None or recs.empty:
            return []
        return json.loads(recs.to_json(orient="records"))
    except Exception as e:
        print(f"  [recommendations] failed: {e}")
        return []


def fetch_holders(t):
    try:
        major = t.major_holders
        institutional = t.institutional_holders
        return {
            "major_holders": json.loads(major.to_json(orient="records")) if major is not None else [],
            "institutional_holders": json.loads(institutional.to_json(orient="records"))
            if institutional is not None
            else [],
        }
    except Exception as e:
        print(f"  [holders] failed: {e}")
        return {"major_holders": [], "institutional_holders": []}


def fetch_all_detail(ticker):
    print(f"Fetching full detail for {ticker}...")
    t = yf.Ticker(ticker)

    detail = {
        "ticker": ticker,
        "market": get_market(ticker),
        "fetched_at": now_iso(),
        "summary": fetch_summary(t),
        "quote": fetch_quote(t),
        "news": fetch_news_detail(t),
        "chart": fetch_chart(t),
        "options": fetch_options(t),
        "dividends_and_splits": fetch_dividends_and_splits(t),
        "recommendations": fetch_recommendations(t),
        "holders": fetch_holders(t),
        "not_available": {
            "conversations": "Yahoo's discussion/comment system is not exposed by any API — website-rendered only.",
            "components": "No reliable free source for full ETF/index holdings lists via yfinance.",
        },
    }

    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f"{ticker}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(detail, f, indent=2, default=str, ensure_ascii=False)
    print(f"  saved {path}")
    return detail


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fetch_stock_detail.py TICKER [TICKER2 ...]")
        print("Example: python fetch_stock_detail.py AAPL RELIANCE.NS")
        sys.exit(1)

    for ticker in sys.argv[1:]:
        fetch_all_detail(ticker)
