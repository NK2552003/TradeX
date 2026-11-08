"""Offline regression tests for production market sync failure boundaries."""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
import sync_market_pipeline as pipeline
import market_news as news


class MarketSyncTests(unittest.TestCase):
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

    def database(self):
        with patch.dict('os.environ', {'SUPABASE_URL': 'https://example.test', 'SUPABASE_SERVICE_ROLE_KEY': 'test-key'}):
            return pipeline.Database()

    def test_failed_database_writes_are_not_counted(self):
        db = self.database()
        with patch.object(db, 'call', side_effect=pipeline.PipelineError('HTTP 403')):
            with self.assertRaises(pipeline.PipelineError):
                db.upsert('stock_quotes', [{'ticker': 'AAPL', 'price': 10}], 'ticker')
        self.assertEqual(dict(db.written), {})

    def test_null_refresh_fields_do_not_erase_metadata(self):
        db = self.database()
        with patch.object(db, 'call', return_value=[{'ticker': 'AAPL'}]) as call:
            db.upsert('stock_fundamentals', [{'ticker': 'AAPL', 'pe_ratio': None, 'eps': 0}], 'ticker')
            self.assertEqual(call.call_args.kwargs['body'], [{'ticker': 'AAPL', 'eps': 0}])
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
            args = MagicMock(dry_run=True, symbols='AAPL', scope=scope, workers=1)
            report = {'errors': [], 'warnings': [], 'symbols': {}}
            with patch.object(pipeline, 'sync_market', return_value=[]) as market, \
                 patch.object(pipeline, 'sync_news') as articles, patch.object(pipeline, 'sync_screeners') as screens:
                pipeline.run(args, report)
                self.assertEqual(market.called, scope != 'news')
                self.assertEqual(articles.called, scope == 'news')
                self.assertEqual(screens.called, scope == 'screeners')

    def test_partial_market_failure_keeps_screeners(self):
        args = MagicMock(dry_run=True, symbols='AAPL', scope='all', workers=1)
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

    def test_retired_listings_are_not_fetched_as_current_companies(self):
        self.assertFalse(set(pipeline.TARGET_TICKERS) & pipeline.RETIRED_SYMBOLS)
        self.assertTrue({'XYZ', 'ETERNAL.NS', 'LTM.NS', 'TMCV.NS', 'TMPV.NS'} <= set(pipeline.TARGET_TICKERS))

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
