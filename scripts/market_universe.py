"""The market universe: exactly the instruments in scripts/data/top-5000-tickers.md.

Run scripts/build_market_universe.py after editing the markdown table. Nothing
else (curated lists, stored volume rankings) may add instruments to the sync.
"""
import json
from pathlib import Path

UNIVERSE_PATH = Path(__file__).resolve().parent / 'data' / 'market_universe.json'


def load_universe(path=UNIVERSE_PATH):
    rows = json.loads(Path(path).read_text(encoding='utf-8'))
    return sorted(rows, key=lambda row: row['rank'])


UNIVERSE = load_universe()
TARGET_TICKERS = [row['ticker'] for row in UNIVERSE]

# Retain these instruments' stored history; never relabel it across a rename
# or demerger. Fetch the current provider listings as distinct instruments.
RETIRED_SYMBOLS = {'SQ', 'ZOMATO.NS', 'TATAMOTORS.NS', 'LTIM.NS'}
