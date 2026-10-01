"""Validate assets and export idempotent SQL seeds. Never connects to a database."""
import json
import math
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets/data'
SEEDS = ROOT / 'database/seeds'


def clean(value):
    if isinstance(value, float) and not math.isfinite(value):
        return None
    if isinstance(value, dict):
        return {k: clean(v) for k, v in value.items()}
    if isinstance(value, list):
        return [clean(v) for v in value]
    return value


def date_value(value):
    if value is None:
        return None
    if isinstance(value, (int, float)) or str(value).isdigit():
        timestamp = float(value)
        if timestamp > 10_000_000_000:
            timestamp /= 1000
        return datetime.fromtimestamp(timestamp, timezone.utc).date().isoformat()
    return str(value)[:10]


def sql(value):
    if value is None:
        return 'NULL'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (dict, list)):
        return "'" + json.dumps(value, ensure_ascii=False, allow_nan=False).replace("'", "''") + "'::jsonb"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def upsert(table, data, keys):
    columns = list(data)
    updates = [c for c in columns if c not in keys]
    return (f"INSERT INTO {table} ({', '.join(columns)}) VALUES ({', '.join(sql(data[c]) for c in columns)}) "
            f"ON CONFLICT ({', '.join(keys)}) DO " +
            (f"UPDATE SET {', '.join(c + ' = EXCLUDED.' + c for c in updates)};" if updates else 'NOTHING;'))


def export():
    # Aggregate the per-file kit outputs for the app without changing their shapes.
    from asset_runtime import read_json, write_json, merge_news
    details = {p.stem: read_json(p, {}) for p in sorted((DATA / 'stock_detail').glob('*.json'))}
    write_json(DATA / 'stock_detail.json', details)
    screens = {p.stem: read_json(p, {}) for p in sorted((DATA / 'screeners').glob('*.json'))}
    write_json(DATA / 'screeners.json', screens)
    all_news = merge_news(read_json(DATA / 'all_news.json', []), read_json(DATA / 'news.json', []),
                          *[d.get('news', []) for d in details.values()])
    write_json(DATA / 'all_news.json', all_news)
    loaded = {}
    for path in sorted(DATA.rglob('*.json')):
        value = clean(json.loads(path.read_text()))
        path.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + '\n')
        loaded[str(path.relative_to(DATA))] = value
    # Topic endpoints may return a common headline under different symbols.
    # Union those associations into the one canonical article export.
    by_link = {a.get('link') or a.get('title'): a for a in loaded['all_news.json']}
    for filename, articles in loaded.items():
        if filename.startswith('by_topic/') and isinstance(articles, list):
            for article in articles:
                key = article.get('link') or article.get('title')
                if key in by_link:
                    row = by_link[key]
                    row['related_tickers'] = sorted(set(row.get('related_tickers', [])) | set(article.get('related_tickers', [])))
    for filename in ['all_news.json', 'news.json']:
        loaded[filename] = list(by_link.values())
        (DATA / filename).write_text(json.dumps(loaded[filename], indent=2, ensure_ascii=False, allow_nan=False) + '\n')

    SEEDS.mkdir(exist_ok=True)
    site = ['BEGIN;', upsert('pricing_catalogues', {'id': 'default', 'catalogue': loaded['pricing_catalogue.json'], 'published': True}, ['id']),
            upsert('public_site_pages', {'id': 'landing', 'content': loaded['landing_page.json'], 'published': True}, ['id']), 'COMMIT;']
    # bool SQL uses actual booleans rather than Python spellings.
    site = [line.replace(' True)', ' true)').replace(' False)', ' false)') for line in site]
    (SEEDS / '03_public_site.sql').write_text('\n'.join(site) + '\n')
    rows = ['BEGIN;']
    quotes = loaded['quotes.json']
    fundamentals = loaded['fundamentals.json']
    details = loaded['stock_detail.json']
    news = loaded['all_news.json']
    screen_rows = {}
    for name, screen in screens.items():
        if isinstance(screen, dict) and isinstance(screen.get('quotes'), list):
            screen_rows[name] = screen['quotes']
        elif isinstance(screen, list):
            screen_rows[name] = screen
        elif name == 'world_indices_by_continent':
            for continent, values in screen.items():
                screen_rows['world_indices_' + continent.lower().replace(' & ', '_and_').replace(' ', '_')] = [
                    {'ticker': t, **v} for t, v in values.items() if isinstance(v, dict)]
        elif name == 'sector_breakdown':
            screen_rows[name] = [v for v in screen.values() if isinstance(v, dict)]
    symbols = set(quotes) | set(details)
    symbols.update(t['ticker'] for t in loaded.get('tickers/universe.json', []))
    symbols.update(r.get('symbol') or r.get('ticker') for values in screen_rows.values() for r in values if r.get('symbol') or r.get('ticker'))
    symbols.update(t for article in news for t in article.get('related_tickers', []) if isinstance(t, str))
    universe_markets = {row['ticker']: row['market'] for row in loaded.get('tickers/universe.json', [])}
    screen_names = {r.get('symbol') or r.get('ticker'): r.get('longName') or r.get('shortName') or r.get('name') for values in screen_rows.values() for r in values}
    for symbol in sorted(symbols):
        q = quotes.get(symbol, {})
        detail = details.get(symbol, {})
        summary = detail.get('summary') or fundamentals.get(symbol, {})
        rows.append(upsert('tickers', {'ticker': symbol, 'market': q.get('market') or detail.get('market') or universe_markets.get(symbol), 'exchange': q.get('exchange'), 'currency': q.get('currency'), 'name': summary.get('name') or screen_names.get(symbol)}, ['ticker']))
    for continent, values in screens.get('world_indices_by_continent', {}).items():
        for symbol, value in values.items():
            if isinstance(value, dict):
                rows.append(upsert('index_metadata', {'ticker': symbol, 'continent': continent}, ['ticker']))
    for sector, value in screens.get('sector_breakdown', {}).items():
        if isinstance(value, dict) and value.get('ticker'):
            rows.append(upsert('sector_metadata', {'ticker': value['ticker'], 'sector_name': sector}, ['ticker']))
    for symbol, quote in quotes.items():
        rows.append(upsert('stock_quotes', {key: quote.get(key) for key in ['ticker','price','previous_close','day_high','day_low','volume','change_pct','updated_at']}, ['ticker']))
    for symbol, detail in details.items():
        rows.append(upsert('stock_details', {'ticker': symbol, 'detail': detail, 'fetched_at': detail['fetched_at']}, ['ticker']))
        for candle in (detail.get('chart') or {}).get('data', []):
            rows.append(upsert('stock_price_history', {'ticker': symbol, 'date': candle['date'][:10], **{k: candle[k] for k in ['open','high','low','close','volume']}}, ['ticker','date']))
    for filename, history in loaded.items():
        if filename.startswith('history/'):
            symbol = history['ticker']
            for candle in history.get('data', []):
                rows.append(upsert('stock_price_history', {'ticker': symbol, 'date': candle['date'][:10], **{k: candle.get(k) for k in ['open','high','low','close','volume']}}, ['ticker','date']))
    exported_at = datetime.now(timezone.utc).isoformat()
    for name, values in screen_rows.items():
        kind = 'crypto' if name.startswith('crypto_') else ('index' if name.startswith('world_indices_') else ('sector' if name == 'sector_breakdown' else 'screener'))
        rows.append(upsert('screener_categories', {'name': name, 'category_type': kind}, ['name']))
        rows.append(f"INSERT INTO market_screener_snapshots(category_id,payload,exported_at) SELECT id,{sql(screens.get(name, values))},{sql(exported_at)} FROM screener_categories WHERE name = {sql(name)} ON CONFLICT(category_id) DO UPDATE SET payload = EXCLUDED.payload, exported_at = EXCLUDED.exported_at;")
        rows.append(f"DELETE FROM screener_results WHERE category_id = (SELECT id FROM screener_categories WHERE name = {sql(name)});")
        for rank, record in enumerate(values, 1):
            symbol = record.get('symbol') or record.get('ticker')
            if not symbol:
                continue
            rows.append(f"INSERT INTO screener_results(category_id,ticker,rank,price,change_pct,extra_data) SELECT id, {sql(symbol)}, {rank}, {sql(record.get('regularMarketPrice', record.get('price')))}, {sql(record.get('regularMarketChangePercent', record.get('change_pct')))}, {sql(record)} FROM screener_categories WHERE name = {sql(name)};")
    for symbol, detail in details.items():
        for expiration, sides in (detail.get('options') or {}).get('chains', {}).items():
            rows.append(upsert('options_expirations', {'ticker': symbol, 'expiration_date': expiration}, ['ticker','expiration_date']))
            selector = f"SELECT id FROM options_expirations WHERE ticker = {sql(symbol)} AND expiration_date = {sql(expiration)}"
            rows.append(f"DELETE FROM options_contracts WHERE expiration_id = ({selector});")
            for side, kind in [('calls','call'), ('puts','put')]:
                for contract in sides.get(side, []):
                    columns = {'contract_type': kind, **{out: contract.get(src) for out, src in [('strike','strike'), ('last_price','lastPrice'), ('bid','bid'), ('ask','ask'), ('volume','volume'), ('open_interest','openInterest'), ('implied_volatility','impliedVolatility'), ('in_the_money','inTheMoney'), ('contract_symbol','contractSymbol')]}}
                    rows.append(f"INSERT INTO options_contracts(expiration_id,{','.join(columns)}) SELECT id,{','.join(sql(v) for v in columns.values())} FROM options_expirations WHERE ticker = {sql(symbol)} AND expiration_date = {sql(expiration)};")
        actions = detail.get('dividends_and_splits') or {}
        for item in actions.get('dividends', []):
            rows.append(upsert('dividends', {'ticker': symbol, 'ex_date': item['date'][:10], 'amount': item['amount']}, ['ticker','ex_date']))
        for item in actions.get('splits', []):
            rows.append(upsert('stock_splits', {'ticker': symbol, 'split_date': item['date'][:10], 'ratio': item['ratio']}, ['ticker','split_date']))
        rows.append(f"DELETE FROM analyst_recommendations WHERE ticker = {sql(symbol)};")
        for rec in detail.get('recommendations', []):
            fields = {'ticker': symbol, 'period': rec.get('period'), **{out: rec.get(src) for out, src in [('strong_buy','strongBuy'), ('buy','buy'), ('hold','hold'), ('sell','sell'), ('strong_sell','strongSell')]}}
            rows.append(f"INSERT INTO analyst_recommendations({','.join(fields)}) VALUES ({','.join(sql(v) for v in fields.values())});")
        rows.append(f"DELETE FROM holders WHERE ticker = {sql(symbol)};")
        for key, kind in [('major_holders','major'), ('institutional_holders','institutional')]:
            for holder in (detail.get('holders') or {}).get(key, []):
                fields = {'ticker': symbol, 'holder_type': kind, 'holder_name': str(holder.get('Holder') or holder.get('Breakdown') or holder.get('Value') or holder),
                          'shares': holder.get('Shares'), 'date_reported': date_value(holder.get('Date Reported')), 'pct_out': holder.get('pctHeld'), 'value': holder.get('Value') if kind == 'institutional' else None}
                rows.append(f"INSERT INTO holders({','.join(fields)}) VALUES ({','.join(sql(v) for v in fields.values())});")
    for symbol, value in fundamentals.items():
        fields = ['market_cap','pe_ratio','forward_pe','peg_ratio','eps','sector','industry','fifty_two_week_high','fifty_two_week_low','fifty_day_average','two_hundred_day_average','dividend_yield','beta','avg_volume','shares_outstanding']
        rows.append(upsert('stock_fundamentals', {'ticker': symbol, **{k: value.get(k) for k in fields if k in value}}, ['ticker']))
    # Canonical main-branch news_articles with integer IDs; link is the natural key.
    for article in news:
        if not article.get('link') or not article.get('title'):
            continue
        fields = ['title','summary','link','publisher','thumbnail_url','content_type','published_at']
        rows.append(upsert('news_articles', {k: article.get(k) for k in fields}, ['link']))
        for symbol in article.get('related_tickers', []):
            if not isinstance(symbol, str):
                continue
            rows.append(f"INSERT INTO news_article_tickers (article_id, ticker) SELECT id, {sql(symbol)} FROM news_articles WHERE link = {sql(article['link'])} ON CONFLICT DO NOTHING;")
    for path, articles in loaded.items():
        if not path.startswith('by_topic/') or not isinstance(articles, list):
            continue
        topic = Path(path).stem
        rows.append(upsert('news_topics', {'name': topic}, ['name']))
        for article in articles:
            if article.get('link'):
                rows.append(f"INSERT INTO news_article_topics (article_id, topic_id) SELECT a.id, t.id FROM news_articles a CROSS JOIN news_topics t WHERE a.link = {sql(article['link'])} AND t.name = {sql(topic)} ON CONFLICT DO NOTHING;")
    rows.append('COMMIT;')
    (SEEDS / '04_market_assets.sql').write_text('\n'.join(rows) + '\n')
    manifest = {'generated_at': datetime.now(timezone.utc).isoformat(), 'quote_count': len(quotes), 'detail_count': len(details), 'history_count': sum(p.startswith('history/') for p in loaded),
                'article_count': len({a.get('link') for a in news}), 'files': sorted(loaded),
                'screeners_source': 'Yahoo Finance kits from Downloads/files (1)', 'news_fetch_limit_per_symbol': 20,
                'universe_count': len(loaded.get('tickers/universe.json', [])), 'screener_category_count': len(screen_rows),
                'source_kits': json.loads((ROOT / 'scripts/source_kits.json').read_text())}
    (DATA / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f"Exported {len(quotes)} quotes, {len(details)} detailed instruments, {manifest['article_count']} articles; SQL seeds under database/seeds.")


if __name__ == '__main__':
    export()
