"""Recover missing history assets from a preserved local SQL export.

Reads only the exporter-generated stock_price_history INSERT grammar; does not
execute SQL or overwrite existing JSON. Useful when generated histories were
omitted from a checkout while the SQL export was retained.
"""
import argparse
import csv
import json
import re
from collections import defaultdict
from pathlib import Path
from asset_runtime import DATA_DIR, read_json, write_json

PATTERN = re.compile(r'^INSERT INTO stock_price_history \(ticker, date, open, high, low, close, volume\) VALUES \((.*?)\) ON CONFLICT')

def restore(source):
    quotes = read_json(DATA_DIR / 'quotes.json', {})
    bars = defaultdict(dict)
    with Path(source).open() as stream:
        for line in stream:
            match = PATTERN.match(line)
            if not match:
                continue
            values = next(csv.reader([match.group(1)], quotechar="'", skipinitialspace=True))
            symbol, date, *numbers = values
            if symbol not in quotes:
                continue
            candle = {'date': date, **{k: None if v == 'NULL' else float(v) for k, v in zip(['open','high','low','close','volume'], numbers)}}
            if candle['volume'] is not None:
                candle['volume'] = int(candle['volume'])
            if all(candle[k] is not None for k in ['open','high','low','close']):
                bars[symbol][date] = candle
    restored = 0
    for symbol, records in bars.items():
        path = DATA_DIR / 'history' / f'{symbol}.json'
        if path.exists():
            continue
        quote = quotes[symbol]
        write_json(path, {'ticker': symbol, 'market': quote.get('market'), 'currency': quote.get('currency'),
            'period': 'exported_snapshot', 'interval': '1d', 'data_source': 'preserved_sql_export',
            'data': [records[d] for d in sorted(records)]})
        restored += 1
    print(f'Restored {restored} missing history assets from existing exported rows')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('sql_export', help='Path to a preserved 04_market_assets.sql')
    restore(parser.parse_args().sql_export)
