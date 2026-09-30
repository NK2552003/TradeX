"""
Periodic Refresh Loop — runs all four finance kit scripts in sequence.
"""

import os
import sys
import time
import subprocess

SCRIPT_DIR = os.path.dirname(__file__)
SCRIPTS = [
    "fetch_ticker_lists.py",
    "fetch_finance_data.py",
    "fetch_stock_detail.py",
    "fetch_news.py",
    "screeners.py",
]


def run_refresh():
    print(f"\n========================================================")
    print(f"Starting Finance Refresh Cycle at {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"========================================================\n")

    for s in SCRIPTS:
        script_path = os.path.join(SCRIPT_DIR, s)
        if os.path.exists(script_path):
            print(f"--> Running {s}...")
            try:
                subprocess.run([sys.executable, script_path], check=True)
            except Exception as e:
                print(f"    Failed running {s}: {e}")

    print("\nRefresh cycle completed.")


if __name__ == "__main__":
    interval = int(os.environ.get("REFRESH_INTERVAL_SECONDS", "300"))
    once = "--once" in sys.argv

    if once:
        run_refresh()
    else:
        print(f"Starting continuous refresh loop every {interval} seconds. Press Ctrl+C to stop.")
        while True:
            run_refresh()
            time.sleep(interval)
