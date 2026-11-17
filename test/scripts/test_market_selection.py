import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from datetime import datetime, timezone

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
import market_selection as selection
import sync_market_pipeline as pipeline
import prepare_client_config as config


class SelectionTests(unittest.TestCase):
    def test_selection_is_exactly_the_ranked_ticker_file(self):
        symbols = selection.select_symbols()
        self.assertEqual(len(symbols), 5000)
        self.assertEqual(len(set(symbols)), 5000)
        self.assertEqual(symbols[:3], ['AAPL', 'NVDA', 'MSFT'])
        self.assertIn('BRK-B', symbols)
        self.assertNotIn('BRK/B', symbols)
        self.assertNotIn('RELIANCE.NS', symbols)

    def test_stored_rows_never_widen_the_universe(self):
        stored = [{'ticker': f'T{i:05}', 'volume': i + 1} for i in range(6000)]
        self.assertEqual(selection.select_symbols(stored), selection.select_symbols())
        self.assertEqual(selection.select_symbols(limit=10), selection.select_symbols()[:10])

    def test_shards_are_disjoint_complete_and_at_most_500(self):
        symbols = selection.select_symbols()
        partitions = [symbols[i::10] for i in range(10)]
        self.assertTrue(all(len(p) <= 500 for p in partitions))
        self.assertEqual(sum(map(len, partitions)), len(set(s for p in partitions for s in p)))
        self.assertEqual(set(symbols), {s for p in partitions for s in p})

    def test_finalize_requires_all_reports_and_excludes_discarded_listings(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            report = {'status': 'passed', 'errors': [], 'dry_run': False, 'symbols': {'AAPL': {'persisted': True}, 'OLD': {}},
                      'requested_symbols': 2, 'discarded_symbols': {'OLD': ['Missing quote']}}
            path = directory / 'market-sync-report-0.json'
            path.write_text(json.dumps(report))
            self.assertEqual(selection.validated_symbols(['AAPL', 'OLD'], directory), ['AAPL'])
            with self.assertRaises(ValueError):
                selection.validated_symbols(['AAPL', 'OLD', 'MSFT'], directory)
            report['status'] = 'running'
            path.write_text(json.dumps(report))
            with self.assertRaises(ValueError):
                selection.validated_symbols(['AAPL', 'OLD'], directory)

    def test_batch_publish_and_invalid_symbols_do_not_overwrite_stored_data(self):
        stamp = datetime.now(timezone.utc).isoformat()
        def fetched(symbol, scope, history_range=None):
            if symbol == 'MISSING':
                return pipeline.market_rows(symbol, {}, {}), ['chart: HTTP 404']
            rows = pipeline.market_rows(symbol, {'meta': {
                'regularMarketPrice': 100, 'regularMarketTime': datetime.now(timezone.utc).timestamp(),
                'instrumentType': 'EQUITY'}}, {})
            rows['quote']['updated_at'] = stamp
            return rows, []
        from unittest.mock import MagicMock
        db = MagicMock()
        db.select.return_value = []
        db.written = {}
        report = {'symbols': {}, 'errors': [], 'warnings': []}
        with patch.object(pipeline, 'fetch_symbol', side_effect=fetched):
            quotes = pipeline.sync_market(db, ['AAPL', 'MSFT', 'MISSING'], 'quotes', 2, report)
        self.assertEqual(len(quotes), 2)
        self.assertEqual(report['errors'], [])
        self.assertIn('MISSING', report['discarded_symbols'])
        writes = {call.args[0]: call.args[1] for call in db.upsert.call_args_list}
        self.assertEqual({q['ticker'] for q in writes['stock_quotes']}, {'AAPL', 'MSFT'})
        self.assertEqual(len([c for c in db.upsert.call_args_list if c.args[0] == 'stock_quotes']), 1)

    def test_provider_outage_is_not_discarded_as_an_invalid_symbol(self):
        report = {'symbols': {}, 'errors': [], 'warnings': []}
        with patch.object(pipeline, 'fetch_symbol', return_value=(
                pipeline.market_rows('AAPL', {}, {}), ['chart: HTTP 429'])):
            pipeline.sync_market(None, ['AAPL'], 'quotes', 1, report)
        self.assertTrue(report['errors'])
        self.assertFalse(report.get('discarded_symbols'))

    def test_database_failure_keeps_a_failed_report(self):
        from unittest.mock import MagicMock
        db = MagicMock()
        db.select.return_value = []
        db.upsert.side_effect = pipeline.PipelineError('HTTP 500')
        rows = pipeline.market_rows('AAPL', {'meta': {
            'regularMarketPrice': 100, 'regularMarketTime': datetime.now(timezone.utc).timestamp()}}, {})
        with patch.object(pipeline, 'fetch_symbol', return_value=(rows, [])):
            with self.assertRaises(pipeline.PipelineError):
                pipeline.sync_market(db, ['AAPL'], 'quotes', 1, {'symbols': {}, 'errors': [], 'warnings': []})


class ClientConfigTests(unittest.TestCase):
    def test_host_environment_overrides_prefixed_file_and_excludes_secrets(self):
        result = config.export_public_settings(
            'NEXT_PUBLIC_SUPABASE_URL=https://old.test\nOPEN_AI_KEY=private\n',
            {'SUPABASE_URL': 'https://new.test', 'SUPABASE_ANON_KEY': 'public',
             'OPENAI_API_KEY': 'secret', 'SUPABASE_SERVICE_ROLE_KEY': 'private',
             'COPILOT_API_URL': 'https://worker.test'})
        self.assertIn('SUPABASE_URL=https://new.test', result)
        self.assertIn('COPILOT_API_URL=https://worker.test', result)
        self.assertNotIn('old.test', result)
        self.assertNotIn('private', result)
        self.assertNotIn('secret', result)


if __name__ == '__main__':
    unittest.main()
