"""
Finance Screeners Kit — Predefined, Custom & Computed Market Screeners.
Outputs directly to `assets/data/` (including `screeners/*.json` and `screeners.json`).
"""

import json
import os
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
OUT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "assets", "data"))
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(os.path.join(OUT_DIR, "screeners"), exist_ok=True)


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def generate_mock_screeners():
    top_gainers = {
        "quotes": [
            {"symbol": "NVDA", "regularMarketPrice": 128.5, "regularMarketChangePercent": 5.41, "regularMarketVolume": 68000000},
            {"symbol": "RELIANCE.NS", "regularMarketPrice": 2950.4, "regularMarketChangePercent": 1.39, "regularMarketVolume": 5123000},
            {"symbol": "MSFT", "regularMarketPrice": 448.2, "regularMarketChangePercent": 1.40, "regularMarketVolume": 21045000},
        ],
        "count": 3,
        "total": 3
    }

    top_losers = {
        "quotes": [
            {"symbol": "INTC", "regularMarketPrice": 20.15, "regularMarketChangePercent": -3.85, "regularMarketVolume": 42000000},
            {"symbol": "BA", "regularMarketPrice": 175.4, "regularMarketChangePercent": -2.10, "regularMarketVolume": 11000000}
        ],
        "count": 2,
        "total": 2
    }

    most_active = {
        "quotes": [
            {"symbol": "AAPL", "regularMarketPrice": 227.5, "regularMarketChangePercent": 1.07, "regularMarketVolume": 48213000},
            {"symbol": "TSLA", "regularMarketPrice": 245.8, "regularMarketChangePercent": 2.16, "regularMarketVolume": 55000000},
            {"symbol": "NVDA", "regularMarketPrice": 128.5, "regularMarketChangePercent": 5.41, "regularMarketVolume": 68000000}
        ],
        "count": 3,
        "total": 3
    }

    world_indices = {
        "Americas": {
            "^GSPC": {"price": 5850.2, "change_pct": 0.4},
            "^DJI": {"price": 42100.5, "change_pct": 0.2},
            "^IXIC": {"price": 18400.1, "change_pct": 0.6}
        },
        "Europe": {
            "^FTSE": {"price": 8300.1, "change_pct": -0.1},
            "^GDAXI": {"price": 19200.4, "change_pct": 0.3}
        },
        "Asia": {
            "^N225": {"price": 38900.5, "change_pct": 0.8},
            "^NSEI": {"price": 25800.2, "change_pct": 0.55},
            "^BSESN": {"price": 84200.1, "change_pct": 0.52}
        },
        "Middle East & Africa": {
            "^CASE30": {"price": 30500.0, "change_pct": 0.15}
        },
        "Oceania": {
            "^AXJO": {"price": 8200.3, "change_pct": 0.25}
        }
    }

    sector_breakdown = {
        "Technology": {"ticker": "XLK", "price": 235.1, "change_pct": 0.8},
        "Financials": {"ticker": "XLF", "price": 48.3, "change_pct": 0.3},
        "Healthcare": {"ticker": "XLV", "price": 145.2, "change_pct": -0.2},
        "Energy": {"ticker": "XLE", "price": 92.4, "change_pct": 1.1}
    }

    crypto_all = [
        {"ticker": "BTC-USD", "price": 64200.5, "change_pct": 2.1},
        {"ticker": "ETH-USD", "price": 3480.2, "change_pct": 1.5},
        {"ticker": "SOL-USD", "price": 148.5, "change_pct": 4.2}
    ]

    screeners_summary = {
        "day_gainers": [
            {"rank": 1, "ticker": "NVDA", "name": "NVIDIA Corporation", "price": 128.5, "change_pct": 5.41, "volume": 68000000},
            {"rank": 2, "ticker": "RELIANCE.NS", "name": "Reliance Industries", "price": 2950.4, "change_pct": 1.39, "volume": 5123000}
        ],
        "day_losers": [
            {"rank": 1, "ticker": "INTC", "name": "Intel Corporation", "price": 20.15, "change_pct": -3.85, "volume": 42000000}
        ],
        "most_active": [
            {"rank": 1, "ticker": "AAPL", "name": "Apple Inc.", "price": 227.5, "change_pct": 1.07, "volume": 48213000},
            {"rank": 2, "ticker": "TSLA", "name": "Tesla Inc.", "price": 245.8, "change_pct": 2.16, "volume": 55000000}
        ],
        "undervalued_growth": [
            {"rank": 1, "ticker": "GOOGL", "name": "Alphabet Inc.", "price": 165.2, "change_pct": 0.85, "pe_ratio": 22.4}
        ],
        "generated_at": now_iso()
    }

    return {
        "top_gainers": top_gainers,
        "top_losers": top_losers,
        "most_active": most_active,
        "world_indices_by_continent": world_indices,
        "sector_breakdown": sector_breakdown,
        "crypto_all": crypto_all,
        "crypto_top_gainers": crypto_all[:2],
        "crypto_top_losers": list(reversed(crypto_all))[:2],
    }, screeners_summary


def save_json(target_filename, data):
    path = os.path.join(OUT_DIR, target_filename)
    parent = os.path.dirname(path)
    os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, default=str, ensure_ascii=False)
    print(f"  saved {path}")


def main():
    print("[Finance Screeners Kit] Running screeners...")
    screeners_map, summary = generate_mock_screeners()

    save_json("screeners.json", summary)

    for name, data in screeners_map.items():
        save_json(os.path.join("screeners", f"{name}.json"), data)

    if DB_ENABLED:
        try:
            conn = dbmod.get_connection()
            dbmod.init_schema(conn)
            cat_id = dbmod.get_or_create_category(conn, "most_active", "predefined")
            dbmod.reset_category_results(conn, cat_id)
            for rank, item in enumerate(summary.get("most_active", []), start=1):
                dbmod.insert_screener_result(conn, cat_id, item["ticker"], rank, price=item.get("price"), change_pct=item.get("change_pct"))
            conn.close()
            print("  [db] Wrote screener results to Postgres successfully.")
        except Exception as e:
            print(f"  [db] Postgres screener write failed: {e}")

    print("[Finance Screeners Kit] Completed successfully.")


if __name__ == "__main__":
    main()
