"""Per-instrument detail sections (the Yahoo Finance tabs) for the market sync.

Every section is fetched independently and failures are reported by name, so
one unavailable tab (for example options on an ADR) never discards the quote,
history or any other tab. Output keys match what the app's instrument screen
renders: news, options, dividends_and_splits, recommendations, holders.
"""
from datetime import date, datetime, timezone
import json
import math

MAX_NEWS = 15
MAX_EXPIRATIONS = 4
MAX_DIVIDENDS = 60
MAX_HOLDERS = 25
CONTRACT_FIELDS = ('contractSymbol', 'strike', 'lastPrice', 'bid', 'ask', 'volume',
                   'openInterest', 'impliedVolatility', 'inTheMoney', 'lastTradeDate')


def clean(value):
    """Strict-JSON-safe copy: NaN/inf -> None, timestamps -> ISO strings."""
    if isinstance(value, dict):
        return {str(k): clean(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [clean(v) for v in value]
    if isinstance(value, float):
        return value if math.isfinite(value) else None
    if isinstance(value, (datetime, date)) or hasattr(value, 'isoformat'):
        return value.isoformat()
    if hasattr(value, 'item'):  # numpy scalar
        return clean(value.item())
    return value


def records(frame, limit=None):
    """DataFrame -> list of plain dict rows (empty list when unavailable)."""
    if frame is None or getattr(frame, 'empty', True):
        return []
    rows = json.loads(frame.reset_index().to_json(orient='records', date_format='iso'))
    return clean(rows[:limit] if limit else rows)


def news_items(raw, limit=MAX_NEWS):
    items = []
    for item in (raw or [])[:limit]:
        content = item.get('content', item) or {}
        link = ((content.get('canonicalUrl') or {}).get('url') or (content.get('clickThroughUrl') or {}).get('url')
                or item.get('link'))
        title = content.get('title') or item.get('title')
        if not title or not link:
            continue
        thumbs = ((content.get('thumbnail') or {}).get('resolutions') or [])
        published = content.get('pubDate') or item.get('providerPublishTime')
        if isinstance(published, (int, float)):
            published = datetime.fromtimestamp(published, timezone.utc).isoformat()
        items.append({
            'title': title, 'summary': content.get('summary') or item.get('summary'), 'link': link,
            'publisher': (content.get('provider') or {}).get('displayName') or item.get('publisher'),
            'thumbnail_url': (thumbs[0].get('url') if thumbs else None) or (content.get('thumbnail') or {}).get('originalUrl'),
            'published_at': published,
        })
    return items


def options_chain(ticker, limit=MAX_EXPIRATIONS):
    expirations = list(ticker.options or [])
    chains = {}
    for expiry in expirations[:limit]:
        chain = ticker.option_chain(expiry)
        chains[expiry] = {side: [{k: row.get(k) for k in CONTRACT_FIELDS} for row in records(frame)]
                          for side, frame in (('calls', chain.calls), ('puts', chain.puts))}
    return {'expirations': expirations, 'chains': chains}


def dividends_and_splits(ticker):
    dividends = ticker.dividends
    splits = ticker.splits
    return {
        'dividends': [{'date': d.isoformat(), 'amount': float(v)} for d, v in dividends.tail(MAX_DIVIDENDS).items()
                      if math.isfinite(float(v))] if dividends is not None else [],
        'splits': [{'date': d.isoformat(), 'ratio': float(v)} for d, v in splits.items()
                   if math.isfinite(float(v))] if splits is not None else [],
    }


def holders(ticker):
    return {
        'major_holders': records(ticker.major_holders),
        'institutional_holders': records(ticker.institutional_holders, MAX_HOLDERS),
        'mutual_fund_holders': records(ticker.mutualfund_holders, MAX_HOLDERS),
    }


SECTIONS = {
    'news': lambda t: news_items(t.news),
    'options': options_chain,
    'dividends_and_splits': dividends_and_splits,
    'recommendations': lambda t: records(t.recommendations),
    'holders': holders,
}


def section_count(name, value):
    if name == 'options':
        return len(value.get('chains', {}))
    if name == 'dividends_and_splits':
        return len(value.get('dividends', [])) + len(value.get('splits', []))
    if name == 'holders':
        return sum(len(rows) for rows in value.values())
    return len(value)


def fetch_sections(ticker, sections=SECTIONS):
    """Return (detail sections, per-section availability, warnings)."""
    detail, availability, warnings = {}, {}, []
    for name, fetch in sections.items():
        try:
            value = clean(fetch(ticker))
        except Exception as error:  # third-party errors can embed URLs; keep only the type
            availability[name] = {'available': False, 'reason': f'fetch failed ({type(error).__name__})'}
            warnings.append(f'{name}: {type(error).__name__}')
            continue
        count = section_count(name, value)
        availability[name] = {'available': count > 0, 'count': count}
        if count:
            detail[name] = value
    return detail, availability, warnings


def whole(value):
    return int(value) if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) else None


def normalized_rows(symbol, detail, fetched_at):
    """Rows for the normalized dividends/splits/analyst/holders tables."""
    actions = detail.get('dividends_and_splits') or {}
    recommendations = [
        {'ticker': symbol, 'period': str(row['period']), 'strong_buy': row.get('strongBuy'), 'buy': row.get('buy'),
         'hold': row.get('hold'), 'sell': row.get('sell'), 'strong_sell': row.get('strongSell'), 'fetched_at': fetched_at}
        for row in detail.get('recommendations') or [] if row.get('period')]
    holder_rows = {}
    groups = detail.get('holders') or {}
    for row in groups.get('major_holders') or []:
        label = row.get('Breakdown') or row.get('index')
        value = row.get('Value')
        if label and isinstance(value, (int, float)):
            holder_rows[('major', str(label))] = {'ticker': symbol, 'holder_type': 'major', 'holder_name': str(label),
                                                  'pct_out': value, 'fetched_at': fetched_at}
    for kind, key in (('institutional', 'institutional_holders'), ('mutual_fund', 'mutual_fund_holders')):
        for row in groups.get(key) or []:
            name = row.get('Holder')
            if not name:
                continue
            reported = row.get('Date Reported')
            holder_rows[(kind, str(name))] = {
                'ticker': symbol, 'holder_type': kind, 'holder_name': str(name), 'shares': whole(row.get('Shares')),
                'date_reported': reported[:10] if isinstance(reported, str) else None,
                'pct_out': row.get('pctHeld') if row.get('pctHeld') is not None else row.get('% Out'),
                'value': whole(row.get('Value')), 'fetched_at': fetched_at}
    return {
        'dividends': [{'ticker': symbol, 'ex_date': d['date'][:10], 'amount': d['amount']}
                      for d in actions.get('dividends') or []],
        'stock_splits': [{'ticker': symbol, 'split_date': s['date'][:10], 'ratio': s['ratio']}
                         for s in actions.get('splits') or []],
        'analyst_recommendations': recommendations,
        'holders': list(holder_rows.values()),
    }
