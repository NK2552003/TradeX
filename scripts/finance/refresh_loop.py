"""
Runs fetch_finance_data.py on a loop, so your JSON files stay fresh
while you develop against them — mimics the "background worker"
from the full implementation plan, but writing to JSON instead of a DB.

Usage:
    python refresh_loop.py

Ctrl+C to stop.
"""

import time
from datetime import datetime

from fetch_finance_data import main as fetch_all

REFRESH_SECONDS = 60  # quotes/fundamentals/news refreshed every 60s
# NOTE: At small ticker counts (10s-100s) this is fine. At full-market scale
# (8,000+ tickers via tickers/*.csv), a full run takes 15-30 minutes and
# downloads 150-300MB — do NOT run this loop with a 60s interval at that
# scale. Set REFRESH_SECONDS to something like 3600 * 12 (twice a day) instead.

if __name__ == "__main__":
    while True:
        print(f"\n=== Refresh started {datetime.utcnow().isoformat()}Z ===")
        try:
            fetch_all()
        except Exception as e:
            print(f"Refresh failed: {e}")
        print(f"=== Sleeping {REFRESH_SECONDS}s ===")
        time.sleep(REFRESH_SECONDS)
