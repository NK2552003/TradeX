"""
Yahoo Finance screeners — most active, gainers, losers, 52-week highs/lows,
dividends, market cap tiers, and more, using yfinance's real screener API
(yf.screen), plus custom EquityQuery filters for categories Yahoo doesn't
predefine.

IMPORTANT — what this can and can't do:
  - Predefined screens (most_actives, day_gainers, day_losers, etc.) are
    genuine Yahoo Finance screener endpoints — real, live market-wide data.
  - Custom queries (52-week gainers/losers, highest dividend, most
    expensive, large/small cap) use real Yahoo screener fields, confirmed
    against the installed yfinance version.
  - "Oversold stocks" has NO equivalent Yahoo screener field (no RSI
    filter exists in their screener API) — this script instead computes
    RSI from price history for tickers you're ALREADY TRACKING, not the
    whole market. It's an approximation, not a true market-wide screen.
  - "Pink sheet stocks" uses an `exchange` filter that may need the exact
    Yahoo exchange code verified — included but flagged for you to check
    against real results.
  - There is NO Yahoo screener category for "trending" as a concept —
    most_actives is used as the closest real proxy, matching what Yahoo's
    own "Trending Now" surfaces typically pull from.

Usage:
    pip install yfinance --break-system-packages
    python screeners.py
"""

import json
import os

import yfinance as yf

OUT_DIR = "data/screeners"


def ensure_dir():
    os.makedirs(OUT_DIR, exist_ok=True)


def save(name, data):
    path = os.path.join(OUT_DIR, f"{name}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, default=str, ensure_ascii=False)
    count = len(data.get("quotes", data)) if isinstance(data, dict) else len(data)
    print(f"  saved {path}  ({count} results)")


def run_predefined(name, count=100):
    """Runs a real Yahoo predefined screener. See yf.PREDEFINED_SCREENER_QUERIES for the full list."""
    try:
        result = yf.screen(name, count=count)
        save(name, result)
        return result
    except Exception as e:
        print(f"  [screen] '{name}' failed: {e}")
        return None


def run_custom(name, query, sort_field, sort_asc=False, count=100):
    try:
        result = yf.screen(query, sortField=sort_field, sortAsc=sort_asc, size=count)
        save(name, result)
        return result
    except Exception as e:
        print(f"  [screen] custom '{name}' failed: {e}")
        return None


# ---------------------------------------------------------------------------
# Predefined Yahoo screens (real, confirmed available in yfinance 1.7.0)
# ---------------------------------------------------------------------------

PREDEFINED_SCREENS = {
    "most_active": "most_actives",
    "top_gainers": "day_gainers",
    "top_losers": "day_losers",
    "small_cap_stocks": "small_cap_gainers",          # closest real Yahoo category
    "aggressive_small_caps": "aggressive_small_caps",
    "growth_technology_stocks": "growth_technology_stocks",
    "undervalued_growth_stocks": "undervalued_growth_stocks",
    "undervalued_large_caps": "undervalued_large_caps",  # closest to "large cap stocks"
    "most_shorted_stocks": "most_shorted_stocks",
    "top_mutual_funds": "top_mutual_funds",
    "top_etfs_us": "top_etfs_us",
    "top_performing_etfs": "top_performing_etfs",
    "technology_etfs": "technology_etfs",
    "bond_etfs": "bond_etfs",
}


# ---------------------------------------------------------------------------
# Custom Yahoo screens (built from confirmed real screener fields)
# ---------------------------------------------------------------------------


def build_custom_screens():
    EQ = yf.EquityQuery

    custom = {}

    # 52-week gainers: big positive move over the past year
    custom["fifty_two_week_gainers"] = (
        EQ("gt", ["fiftytwowkpercentchange", 20]),
        "fiftytwowkpercentchange",
        False,
    )

    # 52-week losers: big negative move over the past year
    custom["fifty_two_week_losers"] = (
        EQ("lt", ["fiftytwowkpercentchange", -20]),
        "fiftytwowkpercentchange",
        True,
    )

    # Highest dividend yield
    custom["highest_dividend_stocks"] = (
        EQ("gt", ["dividendyield", 0]),
        "dividendyield",
        False,
    )

    # Most expensive stocks by share price
    custom["most_expensive_stocks"] = (
        EQ("gt", ["intradayprice", 500]),
        "intradayprice",
        False,
    )

    # Large cap: market cap over $10B
    custom["large_cap_stocks"] = (
        EQ("gt", ["intradaymarketcap", 10_000_000_000]),
        "intradaymarketcap",
        False,
    )

    # Small cap: market cap between $300M and $2B
    custom["small_cap_stocks_by_marketcap"] = (
        EQ("and", [
            EQ("gt", ["intradaymarketcap", 300_000_000]),
            EQ("lt", ["intradaymarketcap", 2_000_000_000]),
        ]),
        "intradaymarketcap",
        False,
    )

    # Pink sheet stocks — exchange code needs verification against live results.
    # "PNK" is Yahoo's typical code for OTC Pink, but confirm once you run this.
    custom["pink_sheet_stocks"] = (
        EQ("eq", ["exchange", "PNK"]),
        "intradaymarketcap",
        False,
    )

    return custom


def run_all_custom_screens(count=100):
    results = {}
    for name, (query, sort_field, sort_asc) in build_custom_screens().items():
        results[name] = run_custom(name, query, sort_field, sort_asc, count=count)
    return results


# ---------------------------------------------------------------------------
# Oversold stocks — approximated via RSI computed from history you already
# have (NOT a true market-wide Yahoo screen — no such field exists there).
# ---------------------------------------------------------------------------


def compute_rsi(closes, period=14):
    if len(closes) < period + 1:
        return None
    gains, losses = [], []
    for i in range(1, len(closes)):
        change = closes[i] - closes[i - 1]
        gains.append(max(change, 0))
        losses.append(max(-change, 0))
    avg_gain = sum(gains[-period:]) / period
    avg_loss = sum(losses[-period:]) / period
    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return round(100 - (100 / (1 + rs)), 2)


def find_oversold(tickers, rsi_threshold=30):
    """
    Computes 14-day RSI per ticker from local history/*.json files (produced
    by fetch_finance_data.py) and flags anything below rsi_threshold.
    Only covers tickers you've already fetched history for.
    """
    oversold = []
    for ticker in tickers:
        path = os.path.join("data", "history", f"{ticker}.json")
        if not os.path.exists(path):
            continue
        with open(path, "r", encoding="utf-8") as f:
            hist = json.load(f)
        closes = [row["close"] for row in hist.get("data", [])]
        rsi = compute_rsi(closes)
        if rsi is not None and rsi < rsi_threshold:
            oversold.append({"ticker": ticker, "rsi_14": rsi})
    oversold.sort(key=lambda x: x["rsi_14"])
    save("oversold_stocks_by_rsi", oversold)
    return oversold


# ---------------------------------------------------------------------------
# World indices by continent (real tickers, not a screen — direct lookups)
# ---------------------------------------------------------------------------

WORLD_INDICES = {
    "Americas": [
        "^GSPC",   # S&P 500 (US)
        "^DJI",    # Dow Jones (US)
        "^IXIC",   # NASDAQ (US)
        "^RUT",    # Russell 2000 (US)
        "^GSPTSE", # TSX (Canada)
        "^BVSP",   # Bovespa (Brazil)
        "^MXX",    # IPC (Mexico)
        "^MERV",   # Merval (Argentina)
        "^IPSA",   # IPSA (Chile)
        "^GSPC",   # (duplicate placeholder if a 10th isn't reliably available)
    ],
    "Europe": [
        "^FTSE",     # FTSE 100 (UK)
        "^GDAXI",    # DAX (Germany)
        "^FCHI",     # CAC 40 (France)
        "^STOXX50E", # Euro Stoxx 50
        "^IBEX",     # IBEX 35 (Spain)
        "^AEX",      # AEX (Netherlands)
        "^SSMI",     # SMI (Switzerland)
        "^OMXS30",   # OMX Stockholm 30 (Sweden)
        "FTSEMIB.MI",# FTSE MIB (Italy)
        "^ATX",      # ATX (Austria)
    ],
    "Asia": [
        "^N225",    # Nikkei 225 (Japan)
        "^HSI",     # Hang Seng (Hong Kong)
        "000001.SS",# Shanghai Composite (China)
        "^BSESN",   # Sensex (India)
        "^NSEI",    # Nifty 50 (India)
        "^KS11",    # KOSPI (South Korea)
        "^TWII",    # Taiwan Weighted
        "^STI",     # Straits Times (Singapore)
        "^JKSE",    # Jakarta Composite (Indonesia)
        "^KLSE",    # FTSE Bursa Malaysia
    ],
    "Middle East & Africa": [
        "^CASE30",  # EGX 30 (Egypt)
        "^TA125.TA",# Tel Aviv 125 (Israel)
        "^J203.JO", # FTSE/JSE All Share (South Africa) — verify exact symbol
    ],
    "Oceania": [
        "^AXJO",  # ASX 200 (Australia)
        "^NZ50",  # NZX 50 (New Zealand)
    ],
}


# ---------------------------------------------------------------------------
# Sector ETFs — real, standard SPDR sector breakdown (11 sectors)
# ---------------------------------------------------------------------------

SECTOR_ETFS = {
    "Technology": "XLK",
    "Financials": "XLF",
    "Healthcare": "XLV",
    "Energy": "XLE",
    "Consumer Discretionary": "XLY",
    "Consumer Staples": "XLP",
    "Industrials": "XLI",
    "Materials": "XLB",
    "Utilities": "XLU",
    "Real Estate": "XLRE",
    "Communication Services": "XLC",
}


# ---------------------------------------------------------------------------
# Crypto — no Yahoo crypto screener exists; static list + computed movers
# ---------------------------------------------------------------------------

CRYPTO_TICKERS = [
    "BTC-USD", "ETH-USD", "BNB-USD", "SOL-USD", "XRP-USD", "ADA-USD",
    "DOGE-USD", "AVAX-USD", "DOT-USD", "MATIC-USD", "LTC-USD", "LINK-USD",
    "TRX-USD", "SHIB-USD", "ATOM-USD", "XLM-USD", "UNI-USD", "ETC-USD",
    "XMR-USD", "FIL-USD", "APT-USD", "ARB-USD", "OP-USD", "NEAR-USD",
    "VET-USD", "ALGO-USD", "ICP-USD", "HBAR-USD", "SAND-USD", "MANA-USD",
]


# ---------------------------------------------------------------------------
# Popular ETFs and Mutual Funds (static reference lists, real tickers)
# ---------------------------------------------------------------------------

POPULAR_ETFS = [
    "SPY", "VOO", "IVV", "QQQ", "VTI", "VEA", "VWO", "AGG", "BND", "GLD",
    "SLV", "ARKK", "XLK", "XLF", "IWM", "DIA", "EFA", "EEM", "TLT", "HYG",
]

POPULAR_MUTUAL_FUNDS = [
    "VFIAX", "FXAIX", "VTSAX", "SWPPX", "VTIAX", "VBTLX", "FCNTX",
    "AGTHX", "VWELX", "DODGX",
]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    ensure_dir()

    print("Running predefined Yahoo screens...")
    for label, screen_name in PREDEFINED_SCREENS.items():
        run_predefined(screen_name, count=100)

    print("\nRunning custom Yahoo screens...")
    run_all_custom_screens(count=100)

    print("\nFetching world indices by continent...")
    all_index_quotes = {}
    for continent, tickers in WORLD_INDICES.items():
        data = yf.download(tickers, period="5d", interval="1d", group_by="ticker", progress=False)
        continent_result = {}
        for t in set(tickers):
            try:
                df = data[t] if len(set(tickers)) > 1 else data
                last = df.dropna().iloc[-1]
                continent_result[t] = {"price": round(float(last["Close"]), 2)}
            except Exception:
                continent_result[t] = None
        all_index_quotes[continent] = continent_result
    save("world_indices_by_continent", all_index_quotes)

    print("\nFetching sector ETF performance...")
    sector_data = {}
    tickers = list(SECTOR_ETFS.values())
    data = yf.download(tickers, period="5d", interval="1d", group_by="ticker", progress=False)
    for sector, ticker in SECTOR_ETFS.items():
        try:
            df = data[ticker].dropna()
            last = df.iloc[-1]
            prev = df.iloc[-2]
            change_pct = round((last["Close"] - prev["Close"]) / prev["Close"] * 100, 2)
            sector_data[sector] = {"ticker": ticker, "price": round(float(last["Close"]), 2), "change_pct": change_pct}
        except Exception:
            sector_data[sector] = None
    save("sector_breakdown", sector_data)

    print("\nFetching crypto movers...")
    crypto_data = yf.download(CRYPTO_TICKERS, period="5d", interval="1d", group_by="ticker", progress=False)
    crypto_quotes = []
    for t in CRYPTO_TICKERS:
        try:
            df = crypto_data[t].dropna()
            last = df.iloc[-1]
            prev = df.iloc[-2]
            change_pct = round((last["Close"] - prev["Close"]) / prev["Close"] * 100, 2)
            crypto_quotes.append({"ticker": t, "price": round(float(last["Close"]), 2), "change_pct": change_pct})
        except Exception:
            continue
    crypto_quotes.sort(key=lambda x: x["change_pct"], reverse=True)
    save("crypto_all", crypto_quotes)
    save("crypto_top_gainers", crypto_quotes[:10])
    save("crypto_top_losers", list(reversed(crypto_quotes))[:10])

    print("\nDone. All screener results in ./data/screeners/")


if __name__ == "__main__":
    main()
