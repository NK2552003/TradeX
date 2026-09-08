"""Small, JSON-only frontend fixture builder. Run with --fetch for Yahoo snapshots.

The supplied fetcher runs in an isolated child with DATABASE_URL removed. A
bounded fetch cannot truncate a database or expand to the whole ticker universe.
Synthetic records always carry source=demo; successful data carries source=yahoo.
"""
import argparse
import json
import math
import os
from pathlib import Path
import random
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/market'
SYMBOLS = [
    ('AAPL', 'Apple Inc.', 227.50, 'Technology'),
    ('MSFT', 'Microsoft Corporation', 425.20, 'Technology'),
    ('NVDA', 'NVIDIA Corporation', 142.85, 'Technology'),
    ('TSLA', 'Tesla, Inc.', 245.10, 'Consumer Cyclical'),
    ('AMZN', 'Amazon.com, Inc.', 198.60, 'Consumer Cyclical'),
    ('GOOGL', 'Alphabet Inc.', 175.80, 'Communication Services'),
    ('RELIANCE.NS', 'Reliance Industries', 1426.40, 'Energy'),
    ('TCS.NS', 'Tata Consultancy Services', 3285.60, 'Technology'),
    ('INFY.NS', 'Infosys Limited', 1542.80, 'Technology'),
    ('HDFCBANK.NS', 'HDFC Bank Limited', 982.40, 'Financial Services'),
    ('ICICIBANK.NS', 'ICICI Bank Limited', 1376.20, 'Financial Services'),
]


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')


def fixtures():
    quotes, fundamentals, history, news = {}, {}, {}, []
    end = datetime(2026, 9, 4, 20, tzinfo=timezone.utc)
    for index, (ticker, name, price, sector) in enumerate(SYMBOLS):
        rng = random.Random(ticker)
        market = 'IN' if ticker.endswith('.NS') else 'US'
        base = dict(ticker=ticker, market=market,
                    currency='INR' if market == 'IN' else 'USD',
                    exchange='NSE' if market == 'IN' else 'NASDAQ',
                    updated_at=end.isoformat(), source='demo')
        days = sorted(end - timedelta(days=n) for n in range(30)
                      if (end - timedelta(days=n)).weekday() < 5)
        rows = []
        close = price * .95
        for n, day in enumerate(days):
            opening = close
            close = price * (.95 + n / len(days) * .05 + math.sin(n*.8 + index)*.012)
            rows.append(dict(date=day.isoformat(), open=round(opening, 2),
                             close=round(close, 2), high=round(max(opening, close)*1.009, 2),
                             low=round(min(opening, close)*.993, 2),
                             volume=rng.randrange(8000000, 80000000)))
        last, prev = rows[-1], rows[-2]
        quotes[ticker] = dict(base, price=last['close'], previous_close=prev['close'],
                             day_high=last['high'], day_low=last['low'], volume=last['volume'],
                             change_pct=round((last['close']/prev['close']-1)*100, 2),
                             price_as_of=last['date'])
        fundamentals[ticker] = dict(base, name=name, sector=sector, industry=sector,
                                    market_cap=round(price*1e9*(index+1)), pe_ratio=round(18+index*2.7, 2),
                                    fifty_two_week_high=round(price*1.28, 2),
                                    fifty_two_week_low=round(price*.72, 2), dividend_yield=.4+index*.1)
        history[ticker] = dict(base, period='1mo', interval='1d', data=rows)
        news.append(dict(ticker=ticker, market=market,
                         title=f'{name}: the levels and catalysts on our research radar',
                         summary=f'Demo research brief for {ticker}. Review the prior session range, '
                         'volume and sector context before updating your trading plan. '
                         'Write down your thesis, invalidation level and the evidence you still need. '
                         'This is sample editorial content for the frontend preview, not a reported news event.',
                         publisher='TraderHub demo desk', link='', source='demo',
                         related_tickers=[ticker], content_type='STORY',
                         published_at=(end-timedelta(hours=index)).isoformat()))
    return quotes, fundamentals, history, news


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--fetch', action='store_true')
    args = parser.parse_args()
    quotes, fundamentals, history, news = fixtures()
    report = {'fetched_at': datetime.now(timezone.utc).isoformat(), 'fetch_requested': args.fetch,
              'symbols': list(quotes), 'yahoo_quotes': 0, 'yahoo_news': 0,
              'note': 'Daily adjusted price snapshots, never a live quote feed. Demo values are labeled per record.'}
    if args.fetch:
        with tempfile.TemporaryDirectory(prefix='tradex-market-') as temp:
            env = dict(os.environ)
            env.pop('DATABASE_URL', None)
            code = """
import sys
sys.path.insert(0, sys.argv[1])
import fetch_finance_data as f
f.US_TICKERS = ['AAPL', 'NVDA', 'MSFT']
f.INDIA_TICKERS = ['RELIANCE.NS', 'INFY.NS', 'HDFCBANK.NS']
f.ALL_TICKERS = f.US_TICKERS + f.INDIA_TICKERS
f.FUNDAMENTALS_LIMIT = 6
f.NEWS_TICKER_LIMIT = 6
f.NEWS_LIMIT_PER_TICKER = 3
f.main()
"""
            try:
                result = subprocess.run([sys.executable, '-u', '-c', code, str(Path(__file__).parent)],
                                        cwd=temp, env=env, timeout=180, capture_output=True, text=True)
                report['fetch_exit_code'] = result.returncode
                report['fetch_log'] = result.stdout[-6000:] + result.stderr[-3000:]
            except subprocess.TimeoutExpired as exc:
                report['fetch_error'] = 'Fetch exceeded 180 seconds; using available files and labeled demo fallback.'
                report['fetch_log'] = (exc.stdout or b'').decode(errors='replace')[-6000:]
            data = Path(temp) / 'data'
            def read(name, default):
                path = data / name
                return json.loads(path.read_text()) if path.exists() else default
            for ticker, quote in read('quotes.json', {}).items():
                if not isinstance(quote.get('price'), (int, float)) or not math.isfinite(quote['price']):
                    continue
                bars = read(f'history/{ticker}.json', {})
                bars['data'] = [r for r in bars.get('data', []) if all(
                    isinstance(r.get(k), (int, float)) and math.isfinite(r[k])
                    for k in ('open', 'high', 'low', 'close', 'volume'))]
                if not bars['data']:
                    continue
                bars['source'] = 'yahoo'
                quote.update(source='yahoo', price_as_of=bars['data'][-1]['date'])
                history[ticker], quotes[ticker] = bars, quote
                report['yahoo_quotes'] += 1
            for ticker, fund in read('fundamentals.json', {}).items():
                fundamentals[ticker] = dict(fund, source='yahoo')
            fetched_news = [dict(n, source='yahoo') for n in read('news.json', []) if n.get('title')]
            report['yahoo_news'] = len(fetched_news)
            if fetched_news:
                news = fetched_news
    for name, content in [('quotes.json', quotes), ('fundamentals.json', fundamentals),
                          ('news.json', news), ('manifest.json', report)]:
        write(OUT / name, content)
    for ticker, bars in history.items():
        write(OUT / 'history' / f'{ticker}.json', bars)
    print(json.dumps({k: v for k, v in report.items() if k != 'fetch_log'}, indent=2))


if __name__ == '__main__':
    main()
