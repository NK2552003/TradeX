#!/usr/bin/env python3
"""Live market sync using the existing Supabase schema; never deletes history.

Use --dry-run to fetch/validate without database access. Every run writes a JSON
coverage report; incomplete upstream data and database failures exit nonzero.
"""
import argparse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import json
import math
import os
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo

from market_news import enrich_article, legacy_image, merge_articles, rss_articles, yahoo_article
from market_universe import RETIRED_SYMBOLS, TARGET_TICKERS


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def load_env():
    path = Path(__file__).resolve().parents[1] / '.env'
    if path.exists():
        for line in path.read_text().splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                key, value = line.split('=', 1)
                os.environ.setdefault(key.strip(), value.strip().strip('\"\''))


class PipelineError(RuntimeError):
    pass


def request(url, *, method='GET', headers=None, body=None, decode=True):
    """Retry transient errors only, without printing keys, bodies or signed URLs."""
    payload = None if body is None else json.dumps(body, allow_nan=False).encode()
    for attempt in range(3):
        req = urllib.request.Request(url, data=payload, method=method,
                                     headers=headers or {'User-Agent': 'Mozilla/5.0'})
        try:
            with urllib.request.urlopen(req, timeout=20) as response:
                data = response.read()
            return json.loads(data) if decode and data else (None if decode else data)
        except urllib.error.HTTPError as error:
            if error.code not in (408, 429, 500, 502, 503, 504) or attempt == 2:
                raise PipelineError(f'HTTP {error.code}') from None
            retry_after = error.headers.get('Retry-After', '')
            delay = min(float(retry_after), 15) if retry_after.isdigit() else 2 ** attempt
        except (OSError, ValueError):
            if attempt == 2:
                raise PipelineError('Network or invalid-response failure') from None
            delay = 2 ** attempt
        time.sleep(delay)


class Database:
    def __init__(self):
        self.url = (os.getenv('SUPABASE_URL') or os.getenv('NEXT_PUBLIC_SUPABASE_URL') or '').rstrip('/')
        key = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_SECRET_KEY')
        if not self.url.startswith('https://') or not key:
            raise PipelineError('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY for writes')
        self.headers = {'apikey': key, 'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'}
        self.written = defaultdict(int)

    def call(self, method, table, *, params=None, body=None, prefer=None):
        url = f'{self.url}/rest/v1/{table}'
        if params:
            url += '?' + urllib.parse.urlencode(params)
        headers = dict(self.headers)
        if prefer:
            headers['Prefer'] = prefer
        try:
            return request(url, method=method, headers=headers, body=body)
        except PipelineError as error:
            raise PipelineError(f'{method} {table}: {error}') from None

    def select(self, table, **params):
        rows = []
        # Offset advances by the actual server page size, including caps <500.
        while True:
            page = self.call('GET', table, params={**params, 'limit': 500, 'offset': len(rows)})
            if not isinstance(page, list):
                raise PipelineError(f'Invalid read response from {table}')
            if not page:
                return rows
            rows.extend(page)

    def upsert(self, table, rows, conflict):
        # PostgREST bulk rows must have identical keys. Omit absent provider
        # fields so a sparse refresh cannot erase existing fundamentals/images.
        groups = defaultdict(list)
        for row in rows:
            clean = {k: v for k, v in row.items() if v is not None}
            groups[tuple(sorted(clean))].append(clean)
        for group in groups.values():
            for start in range(0, len(group), 200):
                chunk = group[start:start + 200]
                saved = self.call('POST', table, params={'on_conflict': conflict}, body=chunk,
                                  prefer='resolution=merge-duplicates,return=representation')
                if not isinstance(saved, list) or len(saved) != len(chunk):
                    raise PipelineError(f'Unconfirmed write to {table}')
                self.written[table] += len(saved)


def finite(value):
    return value if isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value) else None


def first_number(*values):
    return next((finite(v) for v in values if finite(v) is not None), None)


def chart_bars(chart):
    quotes = (chart.get('indicators', {}).get('quote') or [{}])[0]
    try:
        zone = ZoneInfo(chart.get('meta', {}).get('exchangeTimezoneName') or 'UTC')
    except (KeyError, ValueError):
        zone = timezone.utc
    bars = {}
    for index, timestamp in enumerate(chart.get('timestamp') or []):
        values = {field: finite((quotes.get(field) or [])[index])
                  if index < len(quotes.get(field) or []) else None
                  for field in ('open', 'high', 'low', 'close', 'volume')}
        o, h, l, c = (values[field] for field in ('open', 'high', 'low', 'close'))
        if timestamp is None or any(v is None or v < 0 for v in (o, h, l, c)):
            continue
        if h < max(o, l, c) or l > min(o, h, c):
            continue
        volume = values['volume']
        if volume is not None and volume < 0:
            continue
        day = datetime.fromtimestamp(timestamp, zone).date().isoformat()
        bars[day] = {'date': day, **values, 'volume': int(volume) if volume is not None else None}
    return [bars[day] for day in sorted(bars)]


FUNDAMENTALS = {
    'market_cap': 'marketCap', 'pe_ratio': 'trailingPE', 'forward_pe': 'forwardPE',
    'peg_ratio': 'trailingPegRatio', 'eps': 'trailingEps', 'beta': 'beta',
    'fifty_two_week_high': 'fiftyTwoWeekHigh', 'fifty_two_week_low': 'fiftyTwoWeekLow',
    'fifty_day_average': 'fiftyDayAverage', 'two_hundred_day_average': 'twoHundredDayAverage',
    'dividend_yield': 'dividendYield', 'avg_volume': 'averageVolume',
    'shares_outstanding': 'sharesOutstanding',
}


def market_rows(symbol, chart, info):
    meta = chart.get('meta') or {}
    bars = chart_bars(chart)
    timestamp = first_number(info.get('regularMarketTime'), meta.get('regularMarketTime'))
    price = first_number(info.get('regularMarketPrice'), meta.get('regularMarketPrice'))
    previous = first_number(info.get('regularMarketPreviousClose'), info.get('previousClose'), meta.get('previousClose'))
    # chartPreviousClose is the start of the requested range, not yesterday.
    if previous is None and len(bars) >= 2:
        previous = bars[-2]['close']
    ticker = {k: v for k, v in {
        'ticker': symbol, 'name': info.get('longName') or meta.get('longName') or meta.get('shortName'),
        'market': 'IN' if symbol.endswith(('.NS', '.BO')) or symbol in ('^NSEI', '^NSEBANK', '^BSESN')
                  else ('CRYPTO' if meta.get('instrumentType') == 'CRYPTOCURRENCY' or symbol.endswith('-USD') else 'US'),
        'exchange': info.get('exchange') or meta.get('exchangeName'),
        'currency': info.get('currency') or meta.get('currency'),
        'asset_type': info.get('quoteType') or meta.get('instrumentType'), 'last_seen_at': now_iso(),
    }.items() if v is not None}
    quote = None
    if price is not None and price > 0 and timestamp:
        quote = {
            'ticker': symbol, 'price': price, 'previous_close': previous,
            'day_high': first_number(info.get('dayHigh'), meta.get('regularMarketDayHigh')),
            'day_low': first_number(info.get('dayLow'), meta.get('regularMarketDayLow')),
            'volume': first_number(info.get('volume'), meta.get('regularMarketVolume')),
            'change_pct': (price / previous - 1) * 100 if previous and previous > 0 else None,
            'updated_at': datetime.fromtimestamp(timestamp, timezone.utc).isoformat(),
        }
    fundamental = {column: finite(info.get(key)) for column, key in FUNDAMENTALS.items()}
    for column in ('fifty_two_week_high', 'fifty_two_week_low'):
        fundamental[column] = first_number(fundamental[column], meta.get(FUNDAMENTALS[column]))
    for key in ('sector', 'industry'):
        if info.get(key):
            fundamental[key] = info[key][:50]
    fundamental = {k: v for k, v in fundamental.items() if v is not None}
    if fundamental:
        fundamental.update(ticker=symbol, updated_at=now_iso())
    summary = {**fundamental, **{k: info[v] for k, v in {
        'website': 'website', 'description': 'longBusinessSummary', 'employees': 'fullTimeEmployees',
        'country': 'country', 'city': 'city', 'address': 'address1', 'phone': 'phone',
        'target_mean_price': 'targetMeanPrice', 'recommendation': 'recommendationKey',
        'total_revenue': 'totalRevenue', 'profit_margins': 'profitMargins',
        'revenue_growth': 'revenueGrowth', 'earnings_growth': 'earningsGrowth',
        'total_cash': 'totalCash', 'total_debt': 'totalDebt', 'free_cashflow': 'freeCashflow',
    }.items() if info.get(v) is not None}}
    summary.update({k: ticker[k] for k in ('name', 'exchange', 'currency') if k in ticker})
    detail = {'ticker': symbol, 'summary': summary, 'updated_at': now_iso()}
    if quote:
        detail['quote'] = quote
    if bars:
        detail['history'] = bars[-60:]
    return {'ticker': ticker, 'quote': quote, 'fundamental': fundamental,
            'history': [{'ticker': symbol, **bar, 'recorded_at': now_iso()} for bar in bars], 'detail': detail}


def fetch_symbol(symbol, scope):
    warnings = []
    encoded = urllib.parse.quote(symbol, safe='')
    period = '2y' if scope in ('all', 'history') else '1mo'
    chart = {}
    try:
        data = request(f'https://query1.finance.yahoo.com/v8/finance/chart/{encoded}?range={period}&interval=1d')
        chart = (data.get('chart', {}).get('result') or [{}])[0]
    except PipelineError as error:
        warnings.append(f'chart: {error}')
    info = {}
    if scope in ('all', 'quotes'):
        try:
            import yfinance as yf
            # yfinance handles Yahoo's cookie/crumb authentication for fundamentals.
            info = yf.Ticker(symbol).get_info() or {}
        except Exception as error:
            warnings.append(f'fundamentals: {type(error).__name__}')
        if not info.get('longName') and not info.get('shortName'):
            warnings.append('Company profile unavailable')
    rows = market_rows(symbol, chart, info)
    return rows, warnings


def merge_detail(previous, current):
    result = dict(previous or {})
    for key, value in current.items():
        if isinstance(value, dict):
            result[key] = merge_detail(result.get(key), value)
        elif value is not None:
            result[key] = value
    return result


def sync_market(db, symbols, scope, workers, report):
    quotes = []
    existing = {row['ticker']: row['detail'] for row in db.select('stock_details', select='ticker,detail', order='ticker')} if db and scope in ('all', 'quotes') else {}
    counts = defaultdict(int)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for symbol, (rows, warnings) in zip(symbols, pool.map(lambda s: fetch_symbol(s, scope), symbols)):
            history = rows['history']
            quote = rows['quote']
            status = {'bars': len(history), 'latest_date': history[-1]['date'] if history else None,
                      'quote_time': quote['updated_at'] if quote else None,
                      'fundamental_fields': max(0, len(rows['fundamental']) - 2), 'warnings': warnings}
            report['symbols'][symbol] = status
            errors = []
            if scope in ('all', 'quotes') and rows['ticker'].get('asset_type') == 'EQUITY' and 'Company profile unavailable' in warnings:
                errors.append('Company profile unavailable')
            cutoff = datetime.now(timezone.utc) - timedelta(days=7)
            if scope in ('all', 'quotes', 'screeners'):
                if not quote:
                    errors.append('Missing quote')
                elif datetime.fromisoformat(quote['updated_at']) < cutoff:
                    errors.append('Quote older than 7 days')
                else:
                    quotes.append(quote)
            if scope in ('all', 'history'):
                if len(history) < 2:
                    errors.append('Fewer than two valid daily bars')
                elif history[-1]['date'] < cutoff.date().isoformat():
                    errors.append('History older than 7 days')
            for error in errors:
                report['errors'].append(f'{symbol}: {error}')
            if not quote and not history:
                continue  # Never replace real data with zero quotes/empty details.
            if db:
                db.upsert('tickers', [rows['ticker']], 'ticker')
                if scope in ('all', 'quotes'):
                    if quote and datetime.fromisoformat(quote['updated_at']) >= cutoff:
                        db.upsert('stock_quotes', [quote], 'ticker')
                    if rows['fundamental']:
                        db.upsert('stock_fundamentals', [rows['fundamental']], 'ticker')
                    db.upsert('stock_details', [{'ticker': symbol,
                        'detail': merge_detail(existing.get(symbol), rows['detail']), 'fetched_at': now_iso()}], 'ticker')
                if scope in ('all', 'history'):
                    db.upsert('stock_price_history', history, 'ticker,date')
            counts['quotes'] += int(quote is not None)
            counts['history_rows'] += len(history)
            counts['fundamentals'] += int(bool(rows['fundamental']))
            if len(report['symbols']) % 25 == 0:
                print(f'[market] fetched {len(report["symbols"])}/{len(symbols)}', flush=True)
    report['market'] = dict(counts)
    return quotes


def sync_screeners(db, quotes, report):
    groups = {
        'US': [q for q in quotes if not q['ticker'].endswith(('.NS', '.BO', '-USD')) and not q['ticker'].startswith('^')],
        'IN': [q for q in quotes if q['ticker'].endswith(('.NS', '.BO'))],
        'CRYPTO': [q for q in quotes if q['ticker'].endswith('-USD')],
    }
    specs = [('top_gainers', 'US', 'change_pct', True), ('top_losers', 'US', 'change_pct', False),
             ('most_active', 'US', 'volume', True), ('india_top_gainers', 'IN', 'change_pct', True),
             ('india_top_losers', 'IN', 'change_pct', False), ('crypto_all', 'CRYPTO', 'volume', True)]
    report['screeners'] = {}
    if not db:
        return
    db.upsert('screener_categories', [{'name': n, 'category_type': 'GLOBAL' if m == 'US' else m} for n, m, _, _ in specs], 'name')
    categories = {r['name']: r['id'] for r in db.select('screener_categories', select='id,name', order='id')}
    for name, market, field, reverse in specs:
        candidates = [q for q in groups[market] if q.get(field) is not None]
        ranked = sorted(candidates, key=lambda q: q[field], reverse=reverse)[:15]
        if not ranked:
            report['errors'].append(f'{name}: no fresh candidates; kept previous ranking')
            continue
        category = categories[name]
        run_at = now_iso()
        rows = [{'category_id': category, 'ticker': q['ticker'], 'rank': i + 1,
                 'price': q['price'], 'change_pct': q.get('change_pct'), 'extra_data': q, 'run_at': run_at}
                for i, q in enumerate(ranked)]
        # No unique category/ticker constraint exists. Insert first; prune only
        # this category's older run after confirmed writes and snapshot update.
        saved = db.call('POST', 'screener_results', body=rows, prefer='return=representation')
        if not isinstance(saved, list) or len(saved) != len(rows):
            raise PipelineError(f'Unconfirmed screener write: {name}')
        db.written['screener_results'] += len(saved)
        db.upsert('market_screener_snapshots', [{'category_id': category,
                  'payload': {'name': name, 'quotes': ranked}, 'exported_at': run_at}], 'category_id')
        db.call('DELETE', 'screener_results', params={'category_id': f'eq.{category}', 'run_at': f'lt.{run_at}'})
        report['screeners'][name] = len(rows)


def fetch_news(report):
    articles = []
    queries = ['AAPL', 'NVDA', 'MSFT', 'GOOGL', 'AMZN', 'META', 'TSLA', 'JPM',
               'Federal Reserve', 'BTC-USD', 'ETH-USD', 'Sensex', 'Nifty', 'RELIANCE.NS', 'TCS.NS']
    for query in queries:
        try:
            data = request('https://query2.finance.yahoo.com/v1/finance/search?' + urllib.parse.urlencode({'q': query, 'newsCount': 8}))
            articles.extend(a for item in data.get('news', []) if (a := yahoo_article(item)))
        except PipelineError as error:
            report['warnings'].append(f'Yahoo news {query}: {error}')
    for publisher, url in [('Moneycontrol', 'https://www.moneycontrol.com/rss/MCtopnews.xml'),
                           ('Economic Times', 'https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms')]:
        try:
            articles.extend(rss_articles(request(url, decode=False), publisher))
        except Exception as error:
            report['warnings'].append(f'{publisher} RSS: {type(error).__name__}')
    return merge_articles(articles)


def sync_news(db, workers, report):
    articles = fetch_news(report)
    cutoff = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
    future = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
    articles = [a for a in articles if cutoff <= a['published_at'] <= future]
    # Include recent existing articles to repair previously missing images.
    existing = db.select('news_articles', select='title,summary,link,publisher,thumbnail_url,content_type,published_at',
                         published_at=f'gte.{cutoff}', order='id') if db else []
    fresh_count = len(articles)
    # Remove the old pipeline's unrelated generic Unsplash placeholders.
    legacy_images = {a['thumbnail_url'] for a in existing if legacy_image(a.get('thumbnail_url'))}
    for article in existing:
        if legacy_image(article.get('thumbnail_url')):
            article['thumbnail_url'] = None
    articles = merge_articles(existing + articles)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        articles = list(pool.map(enrich_article, articles))
    report['news'] = {'fresh_articles': fresh_count, 'articles': len(articles),
                      'with_images': sum(bool(a.get('thumbnail_url')) for a in articles),
                      'with_summary': sum(bool(a.get('summary')) for a in articles),
                      'missing_images': sum(not bool(a.get('thumbnail_url')) for a in articles)}
    if fresh_count == 0:
        report['errors'].append('No fresh news from providers; retained existing articles')
    if not db or not articles:
        return
    db.upsert('news_articles', [{k: v for k, v in a.items() if not k.startswith('_')} for a in articles], 'link')
    db_articles = db.select('news_articles', select='id,link', published_at=f'gte.{cutoff}', order='id')
    ids = {a['link']: a['id'] for a in db_articles}
    valid = {t['ticker'] for t in db.select('tickers', select='ticker', order='ticker')}
    links = {(ids[a['link']], symbol) for a in articles if a['link'] in ids
             for symbol in a.get('_related_tickers', []) if symbol in valid}
    db.upsert('news_article_tickers', [{'article_id': aid, 'ticker': symbol} for aid, symbol in sorted(links)], 'article_id,ticker')
    # Clear only explicitly identified legacy placeholders, after enrichment.
    for image in legacy_images:
        db.call('PATCH', 'news_articles', params={'thumbnail_url': f'eq.{image}'}, body={'thumbnail_url': None})


def run(args, report):
    if args.scope in ('all', 'quotes'):
        try:
            import yfinance  # noqa: F401
        except ImportError:
            raise PipelineError('Install scripts/requirements.txt before syncing company details') from None
    db = None if args.dry_run else Database()
    symbols = list(dict.fromkeys(args.symbols.split(','))) if args.symbols else list(TARGET_TICKERS)
    if db and not args.symbols and args.scope in ('all', 'history', 'quotes'):
        # Existing displayed instruments need history too, not only the curated list.
        stored = {r['ticker'] for r in db.select('stock_quotes', select='ticker', order='ticker')}
        report['archived_symbols'] = sorted(stored & RETIRED_SYMBOLS)
        symbols = sorted((set(symbols) | stored) - RETIRED_SYMBOLS)
    report['requested_symbols'] = len(symbols)
    quotes = []
    try:
        if args.scope != 'news':
            quotes = sync_market(db, symbols, args.scope, args.workers, report)
        if args.scope in ('all', 'screeners'):
            if report['errors']:
                report['warnings'].append('Kept screeners unchanged because market coverage is incomplete')
            else:
                sync_screeners(db, quotes, report)
        if args.scope in ('all', 'news'):
            sync_news(db, args.workers, report)
    finally:
        report['confirmed_writes'] = dict(db.written) if db else {}


def main(argv=None):
    load_env()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=['all', 'quotes', 'history', 'news', 'screeners'], default=os.getenv('SYNC_SCOPE', 'all'))
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--symbols', help='Explicit comma-separated symbol subset for diagnostics')
    parser.add_argument('--workers', type=int, choices=range(1, 9), default=4)
    parser.add_argument('--report', default='market-sync-report.json')
    args = parser.parse_args(argv)
    report = {'started_at': now_iso(), 'scope': args.scope, 'dry_run': args.dry_run,
              'symbols': {}, 'errors': [], 'warnings': []}
    try:
        if os.getenv('FETCH_LIVE', 'true').lower() == 'false':
            raise PipelineError('FETCH_LIVE=false cannot publish stale assets; run offline tests instead')
        run(args, report)
    except Exception as error:
        # Known errors are sanitized; third-party exception messages can contain URLs/keys.
        report['errors'].append(str(error) if isinstance(error, PipelineError) else type(error).__name__)
    finally:
        report['finished_at'] = now_iso()
        report['status'] = 'failed' if report['errors'] else 'passed'
        Path(args.report).write_text(json.dumps(report, indent=2, allow_nan=False) + '\n')
        print(json.dumps({k: v for k, v in report.items() if k != 'symbols'}, indent=2))
    return 1 if report['errors'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
