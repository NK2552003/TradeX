"""Offline regression tests for production market sync failure boundaries."""
import json
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import MagicMock, patch
from argparse import Namespace

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
import sync_market_pipeline as pipeline
import market_news as news


class MarketSyncTests(unittest.TestCase):
    def args(self, scope):
        return Namespace(dry_run=True, symbols='AAPL', scope=scope, workers=1,
                         symbols_file=None, max_symbols=5000, select_only=None,
                         shard_index=0, shard_count=1,
                         market_only=False, finalize_market=False,
                         reference_market=False)

    def test_bars_require_real_complete_ohlc(self):
        chart = {'timestamp': [1704205800, 1704292200, 1704378600], 'indicators': {'quote': [{
            'open': [10, None, 10], 'high': [12, 13, 8], 'low': [9, 9, 7],
            'close': [11, 12, 10], 'volume': [0, 20, 30]}]}}
        rows = pipeline.chart_bars(chart)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['volume'], 0)

    def test_daily_change_does_not_use_range_start(self):
        chart = {'meta': {'regularMarketPrice': 12, 'regularMarketTime': 1704292200,
                          'chartPreviousClose': 3}, 'timestamp': [1704205800, 1704292200],
                 'indicators': {'quote': [{'open': [10, 11], 'high': [11, 12], 'low': [9, 10],
                                          'close': [10, 12], 'volume': [0, 10]}]}}
        rows = pipeline.market_rows('TEST', chart, {})
        self.assertAlmostEqual(rows['quote']['change_pct'], 20)
        self.assertEqual(rows['quote']['previous_close'], 10)
        self.assertNotIn('pe_ratio', rows['fundamental'])
        self.assertEqual(rows['quote']['updated_at'], '2024-01-03T14:30:00+00:00')

    def test_missing_fetch_never_produces_zero_quote(self):
        rows = pipeline.market_rows('TEST', {}, {})
        self.assertIsNone(rows['quote'])
        self.assertEqual(rows['history'], [])
        self.assertNotIn('quote', rows['detail'])

    def test_short_provider_history_is_discarded_without_failing_partition(self):
        report = {'errors': [], 'warnings': [], 'symbols': {}}
        now = datetime.now(timezone.utc)
        history = [{'date': now.date().isoformat(), 'open': 10, 'high': 11,
                    'low': 9, 'close': 10, 'volume': 1}]
        with patch.object(
            pipeline,
            'fetch_symbol',
            return_value=(
                {
                    'history': history,
                    'quote': {
                        'ticker': 'SHORT',
                        'updated_at': now.isoformat(),
                    },
                    'fundamental': {},
                    'ticker': {'ticker': 'SHORT'},
                    'detail': {},
                },
                [],
            ),
        ):
            pipeline.sync_market(None, ['SHORT'], 'all', 1, report)
        self.assertEqual(report['errors'], [])
        self.assertEqual(
            report['discarded_symbols']['SHORT'],
            ['Fewer than two valid daily bars'],
        )

    def test_missing_quote_with_short_provider_history_is_discarded(self):
        report = {'errors': [], 'warnings': [], 'symbols': {}}
        with patch.object(
            pipeline,
            'fetch_symbol',
            return_value=(
                {
                    'history': [],
                    'quote': None,
                    'fundamental': {},
                    'ticker': {'ticker': 'UNAVAILABLE'},
                    'detail': {},
                },
                [],
            ),
        ):
            pipeline.sync_market(None, ['UNAVAILABLE'], 'all', 1, report)
        self.assertEqual(report['errors'], [])
        self.assertEqual(
            report['discarded_symbols']['UNAVAILABLE'],
            ['Missing quote', 'Fewer than two valid daily bars'],
        )

    def database(self):
        with patch.dict('os.environ', {'SUPABASE_URL': 'https://example.test', 'SUPABASE_SERVICE_ROLE_KEY': 'test-key'}):
            return pipeline.Database()

    def test_failed_database_writes_are_not_counted(self):
        db = self.database()
        with patch.object(db, 'call', side_effect=pipeline.PipelineError('HTTP 403')):
            with self.assertRaises(pipeline.PipelineError):
                db.upsert('stock_quotes', [{'ticker': 'AAPL', 'price': 10}], 'ticker')
        self.assertEqual(dict(db.written), {})

    def test_smart_prune_market_data_deletes_only_outdated_rows(self):
        db = self.database()
        with patch.object(db, 'select', return_value=[{'ticker': 'AAPL'}, {'ticker': 'OLD.NS'}]), \
             patch.object(db, 'call', return_value=None) as call:
            summary = db.prune_market_data(['AAPL'])
        self.assertEqual(summary['removed_tickers'], 1)
        self.assertEqual(
            [(c.args[0], c.args[1]) for c in call.call_args_list],
            [
                ('DELETE', 'tickers'),
                ('DELETE', 'stock_price_history'),
                ('DELETE', 'news_articles'),
            ],
        )
        self.assertEqual(call.call_args_list[0].kwargs['params'], {'ticker': 'in.("OLD.NS")'})

    def test_smart_prune_preserves_curated_reference_assets(self):
        db = self.database()
        with patch.object(
            db,
            'select',
            return_value=[{'ticker': 'AAPL'}, {'ticker': '^GSPC'}, {'ticker': 'GC=F'}],
        ), patch.object(db, 'call', return_value=None) as call:
            summary = db.prune_market_data(['AAPL'])
        self.assertEqual(summary['removed_tickers'], 0)
        self.assertEqual([c.args[1] for c in call.call_args_list], [
            'stock_price_history',
            'news_articles',
        ])

    def test_reference_market_scope_uses_complete_overview_symbol_set(self):
        args = self.args('all')
        args.symbols = None
        args.reference_market = True
        report = {'errors': [], 'warnings': [], 'symbols': {}}
        with patch.object(pipeline, 'sync_market', return_value=[]) as market, \
             patch.object(pipeline, 'sync_news'), patch.object(pipeline, 'sync_screeners'):
            pipeline.run(args, report)
        selected = market.call_args.args[1]
        self.assertEqual(selected, pipeline.REFERENCE_MARKET_SYMBOLS)
        self.assertIn('^GSPC', selected)
        self.assertIn('GC=F', selected)
        self.assertIn('USDINR=X', selected)
        self.assertEqual(len(selected), len(set(selected)))

    def test_null_refresh_fields_do_not_erase_metadata(self):
        db = self.database()
        with patch.object(db, 'call', return_value=[{'ticker': 'AAPL', 'eps': 0}]) as call:
            db.upsert('stock_fundamentals', [{'ticker': 'AAPL', 'pe_ratio': None, 'eps': 0}], 'ticker')
            self.assertEqual(call.call_args_list[0].kwargs['body'], [{'ticker': 'AAPL', 'eps': 0}])
            self.assertEqual(db.verified['stock_fundamentals'], 1)
        merged = pipeline.merge_detail({'summary': {'description': 'Real description', 'eps': 1}},
                                       {'summary': {'description': None, 'eps': 2}})
        self.assertEqual(merged['summary'], {'description': 'Real description', 'eps': 2})

    def test_pagination_obeys_actual_server_row_cap(self):
        db = self.database()
        with patch.object(db, 'call', side_effect=[[{'id': 1}], [{'id': 2}], []]) as call:
            self.assertEqual(len(db.select('tickers', select='id', order='id')), 2)
            self.assertEqual([c.kwargs['params']['offset'] for c in call.call_args_list], [0, 1, 2])

    def test_scopes_do_not_run_unrelated_syncs(self):
        for scope in ['news', 'quotes', 'history', 'screeners']:
            args = self.args(scope)
            report = {'errors': [], 'warnings': [], 'symbols': {}}
            with patch.object(pipeline, 'sync_market', return_value=[]) as market, \
                 patch.object(pipeline, 'sync_news') as articles, patch.object(pipeline, 'sync_screeners') as screens:
                pipeline.run(args, report)
                self.assertEqual(market.called, scope != 'news')
                self.assertEqual(articles.called, scope == 'news')
                self.assertEqual(screens.called, scope == 'screeners')

    def test_partial_market_failure_keeps_screeners(self):
        args = self.args('all')
        report = {'errors': ['Missing quote'], 'warnings': [], 'symbols': {}}
        with patch.object(pipeline, 'sync_market', return_value=[]), patch.object(pipeline, 'sync_news'), \
             patch.object(pipeline, 'sync_screeners') as screens:
            pipeline.run(args, report)
            screens.assert_not_called()

    def test_unconfirmed_write_fails_instead_of_claiming_success(self):
        db = self.database()
        with patch.object(db, 'call', return_value=None):
            with self.assertRaises(pipeline.PipelineError):
                db.upsert('stock_quotes', [{'ticker': 'AAPL', 'price': 10}], 'ticker')
        self.assertEqual(dict(db.written), {})

    def test_failed_screener_insert_never_deletes_previous_ranking(self):
        db = self.database()
        report = {'errors': []}
        quotes = [{'ticker': 'AAPL', 'price': 10, 'change_pct': 2, 'volume': 100}]
        with patch.object(db, 'upsert'), \
             patch.object(db, 'select', return_value=[{'id': 1, 'name': 'top_gainers'}]), \
             patch.object(db, 'call', side_effect=pipeline.PipelineError('HTTP 500')) as call:
            with self.assertRaises(pipeline.PipelineError):
                pipeline.sync_screeners(db, quotes, report)
        self.assertEqual([c.args[0] for c in call.call_args_list], ['POST'])

    def test_universe_is_the_ticker_file(self):
        self.assertEqual(len(pipeline.TARGET_TICKERS), 5000)
        self.assertFalse(set(pipeline.TARGET_TICKERS) & pipeline.RETIRED_SYMBOLS)
        self.assertEqual(pipeline.UNIVERSE_BY_TICKER['BRK-B']['display_symbol'], 'BRK/B')

    def test_universe_publication_upserts_and_removes_only_config_rows(self):
        db = MagicMock()
        db.select.return_value = [{'ticker': 'AAPL'}, {'ticker': 'GONE'}]
        report = {}
        pipeline.publish_universe(db, ['AAPL', 'NVDA'], report)
        self.assertEqual(db.upsert.call_args.args[0], 'market_universe')
        self.assertEqual({r['ticker'] for r in db.upsert.call_args.args[1]}, {'AAPL', 'NVDA'})
        deleted = [c for c in db.call.call_args_list if c.args[0] == 'DELETE']
        self.assertEqual([c.args[1] for c in deleted], ['market_universe'])
        self.assertEqual(report['universe'], {'published': 2, 'removed': 1})

    def test_company_sections_fall_back_to_the_ticker_file(self):
        rows = pipeline.market_rows('AAPL', {}, {})
        self.assertEqual(rows['ticker']['name'], 'Apple Inc. Common Stock')
        self.assertEqual(rows['fundamental']['sector'], 'Technology')

    def test_detail_sections_flow_into_detail_and_normalized_rows(self):
        sections = {
            'recommendations': [{'period': '0m', 'strongBuy': 5, 'buy': 20, 'hold': 10, 'sell': 1, 'strongSell': 0}],
            'dividends_and_splits': {'dividends': [{'date': '2025-02-10T00:00:00-05:00', 'amount': 0.25}],
                                     'splits': [{'date': '2020-08-31T00:00:00-04:00', 'ratio': 4.0}]},
            'holders': {'institutional_holders': [{'Holder': 'Vanguard', 'Shares': 1e9, 'pctHeld': 0.09,
                                                    'Date Reported': '2025-06-30T00:00:00.000'}]},
            'options': {'expirations': ['2026-12-18'], 'chains': {'2026-12-18': {'calls': [], 'puts': []}}},
            'news': [{'title': 'x', 'link': 'https://e.test/x'}],
        }
        availability = {k: {'available': True, 'count': 1} for k in sections}
        rows = pipeline.market_rows('AAPL', {}, {}, sections, availability)
        self.assertEqual(set(sections) | {'availability', 'snapshot'}, set(rows['detail']) & (set(sections) | {'availability', 'snapshot'}))
        extras = rows['extras']
        self.assertEqual(extras['dividends'], [{'ticker': 'AAPL', 'ex_date': '2025-02-10', 'amount': 0.25}])
        self.assertEqual(extras['stock_splits'][0]['split_date'], '2020-08-31')
        self.assertEqual(extras['analyst_recommendations'][0]['strong_buy'], 5)
        self.assertEqual(extras['holders'][0]['shares'], 1_000_000_000)

    def test_failure_produces_report_and_nonzero_exit(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(pipeline, 'load_env'), \
             patch.object(pipeline, 'run', side_effect=pipeline.PipelineError('HTTP 429')):
            path = Path(directory) / 'report.json'
            self.assertEqual(pipeline.main(['--dry-run', '--report', str(path)]), 1)
            self.assertEqual(json.loads(path.read_text())['status'], 'failed')


class NewsTests(unittest.TestCase):
    def test_nested_yahoo_content_picks_original_image_and_real_timestamp(self):
        article = news.yahoo_article({'content': {'title': 'Real headline', 'pubDate': '2026-11-07T15:00:00Z',
            'canonicalUrl': {'url': 'https://example.test/story'}, 'provider': {'displayName': 'Publisher'},
            'thumbnail': {'resolutions': [{'url': 'https://example.test/small.jpg', 'width': 10, 'height': 10},
                {'url': 'https://example.test/large.jpg', 'width': 100, 'height': 100}]}}})
        self.assertEqual(article['thumbnail_url'], 'https://example.test/large.jpg')
        self.assertEqual(article['published_at'], '2026-11-07T15:00:00+00:00')
        self.assertIsNone(article['summary'])

    def test_missing_publication_date_is_not_replaced_with_now(self):
        self.assertIsNone(news.yahoo_article({'title': 'Undated', 'link': 'https://example.test/a'}))

    def test_rss_media_namespace_and_original_publication_date(self):
        data = b'''<rss xmlns:media="http://search.yahoo.com/mrss/"><channel><item><title>Real news</title>
        <link>https://example.test/story</link><pubDate>Fri, 06 Nov 2026 12:00:00 GMT</pubDate>
        <media:thumbnail url="https://example.test/photo.jpg"/><description>&lt;p&gt;Summary&lt;/p&gt;</description>
        </item></channel></rss>'''
        article = news.rss_articles(data, 'Publisher')[0]
        self.assertEqual(article['published_at'], '2026-11-06T12:00:00+00:00')
        self.assertEqual(article['thumbnail_url'], 'https://example.test/photo.jpg')
        self.assertEqual(article['summary'], 'Summary')

    def test_duplicate_articles_keep_images_and_all_ticker_links(self):
        rows = news.merge_articles([
            {'link': 'https://example.test/a', 'thumbnail_url': 'https://example.test/a.jpg', '_related_tickers': ['AAPL']},
            {'link': 'https://example.test/a', 'thumbnail_url': None, '_related_tickers': ['MSFT']}])
        self.assertEqual(rows[0]['_related_tickers'], ['AAPL', 'MSFT'])
        self.assertEqual(rows[0]['thumbnail_url'], 'https://example.test/a.jpg')

    def test_publisher_metadata_is_used_when_provider_has_no_image(self):
        response = MagicMock()
        response.headers = {'Content-Type': 'text/html'}
        response.read.return_value = b'<meta property="og:image" content="/real-photo.jpg"><meta name="description" content="Publisher summary">'
        response.geturl.return_value = 'https://example.test/story'
        response.__enter__.return_value = response
        opener = MagicMock()
        opener.open.return_value = response
        with patch.object(news, '_public_url', side_effect=lambda u: u), \
             patch.object(news.urllib.request, 'build_opener', return_value=opener):
            article = news.enrich_article({'link': 'https://example.test/story'})
        self.assertEqual(article['thumbnail_url'], 'https://example.test/real-photo.jpg')
        self.assertEqual(article['summary'], 'Publisher summary')

    def test_publisher_fetch_blocks_private_network(self):
        with patch.object(news.socket, 'getaddrinfo', return_value=[(0, 0, 0, '', ('127.0.0.1', 443))]):
            with self.assertRaises(ValueError):
                news._public_url('https://example.test/story')


if __name__ == '__main__':
    unittest.main()
