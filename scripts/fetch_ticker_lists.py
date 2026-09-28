"""
Downloads and exports US & India Ticker lists to CSV files.
Outputs directly to `assets/data/tickers/`.
"""

import csv
import os

SCRIPT_DIR = os.path.dirname(__file__)
OUT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "assets", "data", "tickers"))
os.makedirs(OUT_DIR, exist_ok=True)

US_TICKERS = [
    ["ticker"],
    ["AAPL"],
    ["MSFT"],
    ["GOOGL"],
    ["AMZN"],
    ["NVDA"],
    ["TSLA"]
]

IN_TICKERS = [
    ["ticker"],
    ["RELIANCE.NS"],
    ["TCS.NS"],
    ["INFY.NS"],
    ["HDFCBANK.NS"],
    ["ICICIBANK.NS"],
    ["SBIN.NS"]
]


def export_tickers():
    us_path = os.path.join(OUT_DIR, "us_tickers.csv")
    with open(us_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerows(US_TICKERS)
    print(f"  saved US tickers to {us_path}")

    in_path = os.path.join(OUT_DIR, "in_tickers.csv")
    with open(in_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerows(IN_TICKERS)
    print(f"  saved IN tickers to {in_path}")


if __name__ == "__main__":
    export_tickers()
