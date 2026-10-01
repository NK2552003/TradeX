"""
Downloads the full ticker universe for US (NASDAQ + NYSE) and India (NSE)
and saves them as CSV files that fetch_finance_data.py loads automatically.

Run this ONCE (or occasionally, e.g. monthly) to refresh your ticker list —
NOT part of the regular data-refresh cycle.

Usage:
    pip install requests --break-system-packages
    python fetch_ticker_lists.py

Output:
    tickers/us_tickers.csv   (~8,000+ symbols: NASDAQ + NYSE + AMEX)
    tickers/in_tickers.csv   (~2,000 symbols: NSE equity list, .NS suffix added)

Sources:
    US:    NASDAQ Trader symbol directory (official, free, public)
           https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqlisted.txt
           https://www.nasdaqtrader.com/dynamic/SymDir/otherlisted.txt
    India: NSE equity list (official, free, public CSV)
           https://archives.nseindia.com/content/equities/EQUITY_L.csv
"""

import csv
import os
from asset_runtime import DATA_DIR as ASSET_DIR, read_json, write_json, merge_news
import requests

OUT_DIR = str(ASSET_DIR / "tickers")
os.makedirs(OUT_DIR, exist_ok=True)

HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; ticker-list-fetcher/1.0)"
}


def fetch_us_tickers():
    print("Fetching NASDAQ-listed symbols...")
    nasdaq = requests.get(
        "https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqlisted.txt",
        headers=HEADERS, timeout=30,
    ).text

    print("Fetching NYSE/AMEX-listed symbols...")
    other = requests.get(
        "https://www.nasdaqtrader.com/dynamic/SymDir/otherlisted.txt",
        headers=HEADERS, timeout=30,
    ).text

    tickers = set()

    for line in nasdaq.splitlines()[1:-1]:  # skip header + footer line
        parts = line.split("|")
        if len(parts) > 1 and parts[0] and parts[0] != "Symbol":
            tickers.add(parts[0].strip())

    for line in other.splitlines()[1:-1]:
        parts = line.split("|")
        if len(parts) > 0 and parts[0] and parts[0] != "ACT Symbol":
            tickers.add(parts[0].strip())

    # Drop obviously invalid/test symbols (very short lists sometimes include these)
    tickers = {t for t in tickers if t and "$" not in t and len(t) <= 6}

    path = os.path.join(OUT_DIR, "us_tickers.csv")
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["ticker"])
        for t in sorted(tickers):
            writer.writerow([t])

    print(f"  saved {len(tickers)} US tickers -> {path}")


def fetch_india_tickers():
    print("Fetching NSE equity list...")
    resp = requests.get(
        "https://archives.nseindia.com/content/equities/EQUITY_L.csv",
        headers=HEADERS, timeout=30,
    )
    resp.raise_for_status()
    lines = resp.text.splitlines()

    tickers = []
    reader = csv.DictReader(lines)
    for row in reader:
        symbol = row.get("SYMBOL", "").strip()
        if symbol:
            tickers.append(f"{symbol}.NS")

    path = os.path.join(OUT_DIR, "in_tickers.csv")
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["ticker"])
        for t in sorted(set(tickers)):
            writer.writerow([t])

    print(f"  saved {len(tickers)} India tickers -> {path}")


if __name__ == "__main__":
    for fetch in [fetch_us_tickers, fetch_india_tickers]:
        try:
            fetch()
        except Exception as error:
            print(f'{fetch.__name__} failed; retaining existing list: {error}')
    universe = []
    for market, filename in [('US', 'us_tickers.csv'), ('IN', 'in_tickers.csv')]:
        path = os.path.join(OUT_DIR, filename)
        if os.path.exists(path):
            with open(path, encoding='utf-8') as source:
                universe.extend({'ticker': row['ticker'], 'market': market} for row in csv.DictReader(source))
    if not universe:
        raise RuntimeError('No ticker universe available')
    write_json(ASSET_DIR / 'tickers/universe.json', universe)
    print("\nDone. fetch_finance_data.py will auto-load these CSVs if present.")
    print("NOTE: NSE's server can be strict about request headers/rate — if")
    print("the India fetch fails, download EQUITY_L.csv manually from")
    print("nseindia.com and place it at tickers/in_tickers.csv (ticker column,")
    print("with .NS suffix added to each symbol).")
