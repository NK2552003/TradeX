#!/usr/bin/env python3
"""Rebuild scripts/data/market_universe.json from scripts/data/top-5000-tickers.md.

The markdown table is the single source of truth for which instruments the
market pipeline, Supabase tables and the app's Market Intelligence screens cover.
"""
import json
import re
from pathlib import Path

DATA = Path(__file__).resolve().parent / 'data'
SOURCE = DATA / 'top-5000-tickers.md'
TARGET = DATA / 'market_universe.json'

ROW = re.compile(r'^\|\s*(\d+)\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*$')


def yahoo_symbol(display):
    """Map NASDAQ screener notation to the Yahoo Finance symbol."""
    symbol = display.strip().upper()
    if symbol.endswith('.WS'):
        return symbol[:-3] + '-WT'
    return symbol.replace('/', '-').replace('.', '-')


def parse_market_cap(label):
    match = re.fullmatch(r'\$([\d.]+)([TBMK]?)', label.strip())
    if not match:
        return None
    scale = {'T': 1e12, 'B': 1e9, 'M': 1e6, 'K': 1e3, '': 1}[match[2]]
    return int(float(match[1]) * scale)


def parse(text):
    rows = []
    for line in text.splitlines():
        match = ROW.match(line)
        if not match:
            continue
        rank, display, company, exchange, sector, cap = match.groups()
        rows.append({
            'rank': int(rank), 'ticker': yahoo_symbol(display), 'display_symbol': display.strip(),
            'name': company, 'exchange': exchange, 'sector': None if sector in ('', '-') else sector,
            'market_cap': parse_market_cap(cap),
        })
    tickers = [r['ticker'] for r in rows]
    if len(set(tickers)) != len(tickers):
        raise ValueError('Duplicate symbols in the ticker file')
    return rows


if __name__ == '__main__':
    universe = parse(SOURCE.read_text(encoding='utf-8'))
    TARGET.write_text(json.dumps(universe, indent=1) + '\n', encoding='utf-8')
    print(f'Wrote {len(universe)} instruments to {TARGET}')
