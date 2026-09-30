"""
Stock Detail Kit — Per-stock "everything" fetcher.
Pulls all detail available for a ticker into a single combined JSON file:
summary, quote, dedicated news, price history chart, options chains, dividends & splits,
recommendations, and holders.

Outputs directly to `assets/data/stock_detail/<TICKER>.json` and `assets/data/stock_detail.json`.
"""

import json
import os
import sys
from datetime import datetime, timezone

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
OUT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "assets", "data", "stock_detail"))
os.makedirs(OUT_DIR, exist_ok=True)


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def get_market(ticker):
    return "IN" if ticker.endswith(".NS") or ticker.endswith(".BO") else "US"


def get_currency(ticker):
    return "INR" if get_market(ticker) == "IN" else "USD"


def get_exchange(ticker):
    if ticker.endswith(".NS"):
        return "NSE"
    if ticker.endswith(".BO"):
        return "BSE"
    return "NASDAQ"


def fetch_summary_live(t):
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
        print(f"  [summary] failed for {t.ticker}: {e}")
        return None


def fetch_quote_live(t):
    try:
        fi = t.fast_info
        price = round(float(fi["last_price"]), 2)
        prev = round(float(fi["previous_close"]), 2) if fi.get("previous_close") else None
        return {
            "price": price,
            "previous_close": prev,
            "day_high": round(float(fi["day_high"]), 2) if fi.get("day_high") else price,
            "day_low": round(float(fi["day_low"]), 2) if fi.get("day_low") else price,
            "volume": int(fi["last_volume"]) if fi.get("last_volume") else 0,
            "change_pct": round((price - prev) / prev * 100, 2) if prev else 0.0,
            "currency": fi.get("currency") or get_currency(t.ticker),
            "market_cap": fi.get("market_cap"),
            "updated_at": now_iso(),
        }
    except Exception as e:
        print(f"  [quote] failed for {t.ticker}: {e}")
        return None


def fetch_news_detail_live(t, limit=20):
    try:
        articles = []
        for item in (t.news or [])[:limit]:
            content = item.get("content", item)
            thumb = None
            tb = content.get("thumbnail") or item.get("thumbnail")
            if isinstance(tb, dict):
                res = tb.get("resolutions") or []
                thumb = res[0].get("url") if res else tb.get("url")
            articles.append({
                "ticker": t.ticker,
                "title": content.get("title") or item.get("title"),
                "summary": content.get("summary") or content.get("description") or item.get("summary"),
                "link": (content.get("canonicalUrl", {}) or {}).get("url") or item.get("link"),
                "publisher": (content.get("provider", {}) or {}).get("displayName") or item.get("publisher"),
                "thumbnail_url": thumb,
                "related_tickers": content.get("relatedTickers") or item.get("relatedTickers") or [t.ticker],
                "content_type": content.get("contentType") or item.get("type") or "STORY",
                "published_at": content.get("pubDate") or item.get("providerPublishTime") or now_iso(),
            })
        return articles
    except Exception as e:
        print(f"  [news] failed for {t.ticker}: {e}")
        return []


def fetch_chart_live(t, period="6mo", interval="1d"):
    try:
        hist = t.history(period=period, interval=interval)
        records = []
        for date, row in hist.iterrows():
            records.append({
                "date": date.isoformat(),
                "open": round(float(row["Open"]), 2),
                "high": round(float(row["High"]), 2),
                "low": round(float(row["Low"]), 2),
                "close": round(float(row["Close"]), 2),
                "volume": int(row["Volume"]) if row["Volume"] == row["Volume"] else 0,
            })
        return {"period": period, "interval": interval, "data": records}
    except Exception as e:
        print(f"  [chart] failed for {t.ticker}: {e}")
        return None


def fetch_options_live(t):
    try:
        expirations = t.options
        if not expirations:
            return {"expirations": [], "chains": {}}
        chains = {}
        for exp in expirations[:3]:
            try:
                chain = t.option_chain(exp)
                chains[exp] = {
                    "calls": json.loads(chain.calls.to_json(orient="records")),
                    "puts": json.loads(chain.puts.to_json(orient="records")),
                }
            except Exception:
                continue
        return {"expirations": list(expirations), "chains": chains}
    except Exception:
        return {"expirations": [], "chains": {}}


def fetch_dividends_and_splits_live(t):
    try:
        divs = t.dividends
        splits = t.splits
        return {
            "dividends": [{"date": d.isoformat(), "amount": float(v)} for d, v in divs.items()],
            "splits": [{"date": d.isoformat(), "ratio": float(v)} for d, v in splits.items()],
        }
    except Exception:
        return {"dividends": [], "splits": []}


def fetch_recommendations_live(t):
    try:
        recs = t.recommendations
        if recs is None or recs.empty:
            return []
        return json.loads(recs.to_json(orient="records"))
    except Exception:
        return []


def fetch_holders_live(t):
    try:
        major = t.major_holders
        institutional = t.institutional_holders
        return {
            "major_holders": json.loads(major.to_json(orient="records")) if major is not None else [],
            "institutional_holders": json.loads(institutional.to_json(orient="records")) if institutional is not None else [],
        }
    except Exception:
        return {"major_holders": [], "institutional_holders": []}


def generate_mock_detail(ticker):
    market = get_market(ticker)
    is_in = market == "IN"
    base_price = 2950.4 if ticker == "RELIANCE.NS" else (4215.0 if ticker == "TCS.NS" else (227.5 if ticker == "AAPL" else 448.2))
    name = {
        "AAPL": "Apple Inc.",
        "MSFT": "Microsoft Corporation",
        "GOOGL": "Alphabet Inc.",
        "AMZN": "Amazon.com Inc.",
        "TSLA": "Tesla Inc.",
        "NVDA": "NVIDIA Corporation",
        "RELIANCE.NS": "Reliance Industries Limited",
        "TCS.NS": "Tata Consultancy Services",
        "INFY.NS": "Infosys Limited",
        "HDFCBANK.NS": "HDFC Bank Limited",
        "ICICIBANK.NS": "ICICI Bank Limited",
    }.get(ticker, ticker)

    return {
        "ticker": ticker,
        "market": market,
        "fetched_at": now_iso(),
        "summary": {
            "name": name,
            "sector": "Energy & Retail" if is_in else "Technology",
            "industry": "Conglomerate" if is_in else "Consumer Electronics",
            "website": f"https://www.{ticker.lower().replace('.ns', '')}.com",
            "description": f"{name} is a leading player in the market delivering high value to global investors.",
            "market_cap": 20000000000000 if is_in else 3500000000000,
            "pe_ratio": 28.4 if is_in else 32.1,
            "forward_pe": 25.1,
            "peg_ratio": 1.9,
            "eps": 104.5 if is_in else 6.9,
            "dividend_yield": 0.4,
            "beta": 1.1,
            "fifty_two_week_high": round(base_price * 1.15, 2),
            "fifty_two_week_low": round(base_price * 0.82, 2),
            "fifty_day_average": round(base_price * 0.98, 2),
            "two_hundred_day_average": round(base_price * 0.93, 2),
            "avg_volume": 55000000,
            "shares_outstanding": 15400000000,
            "float_shares": 15300000000,
            "held_percent_insiders": 0.45 if is_in else 0.001,
            "held_percent_institutions": 0.35 if is_in else 0.62,
            "short_ratio": 1.4,
            "target_mean_price": round(base_price * 1.2, 2),
            "recommendation": "buy",
            "number_of_analyst_opinions": 38,
            "employees": 164000,
            "country": "India" if is_in else "United States",
            "exchange": get_exchange(ticker),
        },
        "quote": {
            "price": base_price,
            "previous_close": round(base_price * 0.988, 2),
            "day_high": round(base_price * 1.01, 2),
            "day_low": round(base_price * 0.985, 2),
            "volume": 5123000 if is_in else 48213000,
            "change_pct": 1.25,
            "currency": get_currency(ticker),
            "market_cap": 20000000000000 if is_in else 3500000000000,
            "updated_at": now_iso(),
        },
        "news": [
            {
                "ticker": ticker,
                "title": f"{name} Reports Strong Financial Results and Market Expansion",
                "summary": f"Key momentum seen across major operational units with bullish analyst outlook for {ticker}.",
                "link": f"https://finance.yahoo.com/news/{ticker.lower()}-earnings-report",
                "publisher": "Reuters",
                "thumbnail_url": "https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=500",
                "related_tickers": [ticker],
                "content_type": "STORY",
                "published_at": now_iso(),
            },
            {
                "ticker": ticker,
                "title": f"Analyst Sentiment Remains Positive for {ticker} Following Strategic Roadmap Update",
                "summary": "Institutional investors double down on growth expectations amidst broader macroeconomic tailwinds.",
                "link": f"https://finance.yahoo.com/news/{ticker.lower()}-analyst-update",
                "publisher": "Bloomberg",
                "thumbnail_url": "https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?w=500",
                "related_tickers": [ticker],
                "content_type": "STORY",
                "published_at": now_iso(),
            }
        ],
        "chart": {
            "period": "6mo",
            "interval": "1d",
            "data": [
                {"date": "2026-08-10T00:00:00", "open": round(base_price*0.95, 2), "high": round(base_price*0.97, 2), "low": round(base_price*0.94, 2), "close": round(base_price*0.96, 2), "volume": 4500000},
                {"date": "2026-08-11T00:00:00", "open": round(base_price*0.96, 2), "high": round(base_price*0.99, 2), "low": round(base_price*0.95, 2), "close": round(base_price*0.98, 2), "volume": 5200000},
                {"date": "2026-08-12T00:00:00", "open": round(base_price*0.98, 2), "high": round(base_price*1.01, 2), "low": round(base_price*0.97, 2), "close": base_price, "volume": 5123000},
            ]
        },
        "options": {
            "expirations": ["2026-10-16", "2026-11-20", "2026-12-18"],
            "chains": {
                "2026-10-16": {
                    "calls": [
                        {
                            "strike": round(base_price * 1.05, 1),
                            "lastPrice": 3.2,
                            "bid": 3.1,
                            "ask": 3.3,
                            "volume": 1200,
                            "openInterest": 4500,
                            "impliedVolatility": 0.25,
                            "inTheMoney": False,
                            "contractSymbol": f"{ticker}261016C00230000"
                        }
                    ],
                    "puts": [
                        {
                            "strike": round(base_price * 0.95, 1),
                            "lastPrice": 2.8,
                            "bid": 2.7,
                            "ask": 2.9,
                            "volume": 850,
                            "openInterest": 3100,
                            "impliedVolatility": 0.24,
                            "inTheMoney": False,
                            "contractSymbol": f"{ticker}261016P00210000"
                        }
                    ]
                }
            }
        },
        "dividends_and_splits": {
            "dividends": [{"date": "2026-08-01T00:00:00", "amount": 0.25}],
            "splits": [{"date": "2020-08-31T00:00:00", "ratio": 4.0}]
        },
        "recommendations": [
            {"period": "0m", "strongBuy": 12, "buy": 22, "hold": 5, "sell": 1, "strongSell": 0}
        ],
        "holders": {
            "major_holders": [{"Value": "0.05", "Breakdown": "% of Shares Held by All Insiders"}],
            "institutional_holders": [
                {"Holder": "Vanguard Group Inc", "Shares": 1300000000, "Date Reported": "2026-06-30", "% Out": 0.084, "Value": 295000000000}
            ]
        },
        "not_available": {
            "conversations": "Yahoo's discussion/comment system is not exposed by any API — website-rendered only.",
            "components": "No reliable free source for full ETF/index holdings lists via yfinance."
        }
    }


def fetch_all_detail(ticker):
    print(f"Fetching full detail for {ticker}...")
    detail = None

    if YFINANCE_AVAILABLE:
        try:
            t = yf.Ticker(ticker)
            market = get_market(ticker)
            summary = fetch_summary_live(t)
            quote = fetch_quote_live(t)
            news = fetch_news_detail_live(t)
            chart = fetch_chart_live(t)
            options = fetch_options_live(t)
            div_splits = fetch_dividends_and_splits_live(t)
            recommendations = fetch_recommendations_live(t)
            holders = fetch_holders_live(t)

            if summary or quote:
                detail = {
                    "ticker": ticker,
                    "market": market,
                    "fetched_at": now_iso(),
                    "summary": summary,
                    "quote": quote,
                    "news": news,
                    "chart": chart,
                    "options": options,
                    "dividends_and_splits": div_splits,
                    "recommendations": recommendations,
                    "holders": holders,
                    "not_available": {
                        "conversations": "Yahoo's discussion/comment system is not exposed by any API — website-rendered only.",
                        "components": "No reliable free source for full ETF/index holdings lists via yfinance."
                    }
                }
        except Exception as e:
            print(f"  Live fetch failed for {ticker}: {e}. Falling back to mock data.")

    if not detail:
        detail = generate_mock_detail(ticker)

    path = os.path.join(OUT_DIR, f"{ticker}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(detail, f, indent=2, default=str, ensure_ascii=False)
    print(f"  saved {path}")

    # Also update single stock_detail.json summary file under assets/data/
    summary_path = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "assets", "data", "stock_detail.json"))
    summary_dict = {}
    if os.path.exists(summary_path):
        try:
            with open(summary_path, "r", encoding="utf-8") as f:
                summary_dict = json.load(f)
        except Exception:
            summary_dict = {}
    summary_dict[ticker] = detail
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(summary_dict, f, indent=2, default=str, ensure_ascii=False)

    if DB_ENABLED:
        try:
            conn = dbmod.get_connection()
            dbmod.init_schema(conn)
            dbmod.upsert_ticker(conn, ticker, market=detail["market"], name=(detail.get("summary") or {}).get("name"))
            if detail.get("quote"):
                dbmod.upsert_quote(conn, {**detail["quote"], "ticker": ticker, "market": detail["market"]})
            if detail.get("summary"):
                dbmod.upsert_fundamentals(conn, {**detail["summary"], "ticker": ticker, "market": detail["market"]})
            conn.close()
            print(f"  [db] wrote full detail for {ticker} to Postgres")
        except Exception as e:
            print(f"  [db] failed for {ticker}: {e}")

    return detail


if __name__ == "__main__":
    tickers = sys.argv[1:] if len(sys.argv) > 1 else ["AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "NVDA", "RELIANCE.NS", "TCS.NS", "INFY.NS", "HDFCBANK.NS", "ICICIBANK.NS"]
    for ticker in tickers:
        fetch_all_detail(ticker)
