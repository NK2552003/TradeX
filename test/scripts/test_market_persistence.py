"""Persistence regressions for write confirmation and read-back verification."""
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
import sync_market_pipeline as pipeline
import market_selection
from market_verification import confirm_rows


class StoredDatabase(pipeline.Database):
    """PostgREST transport stand-in backed by an actual temporary SQLite file."""
    def __init__(self, path):
        from collections import defaultdict
        self.written, self.verified = defaultdict(int), defaultdict(int)
        self.path = path
        self.connection = sqlite3.connect(path)
        self.connection.execute('CREATE TABLE saved (collection TEXT, identity TEXT, payload TEXT, PRIMARY KEY(collection, identity))')
        self.saved_quotes = threading.Event()
        self.fail_table = None

    def call(self, method, table, *, params=None, body=None, prefer=None):
        if method == 'POST':
            if table == self.fail_table:
                raise pipeline.PipelineError('Database write rejected')
            keys = params['on_conflict'].split(',')
            for row in body:
                identity = json.dumps([row[key] for key in keys])
                self.connection.execute('INSERT OR REPLACE INTO saved VALUES (?, ?, ?)',
                                        (table, identity, json.dumps(row)))
            self.connection.commit()
            if table == 'stock_quotes':
                self.saved_quotes.set()
            return json.loads(json.dumps(body))
        self_test_rows = [json.loads(row[0]) for row in self.connection.execute(
            'SELECT payload FROM saved WHERE collection=? ORDER BY identity', (table,))]
        for key, value in (params or {}).items():
            if isinstance(value, str) and value.startswith('in.('):
                accepted = json.loads('[' + value[4:-1] + ']')
                self_test_rows = [row for row in self_test_rows if row.get(key) in accepted]
        offset = (params or {}).get('offset', 0)
        return self_test_rows[offset:offset + (params or {}).get('limit', 500)]


class PersistenceTests(unittest.TestCase):
    def db(self):
        with patch.dict('os.environ', {'SUPABASE_URL': 'https://example.test', 'SUPABASE_SERVICE_ROLE_KEY': 'test'}):
            return pipeline.Database()

    def test_correct_count_with_wrong_symbol_or_price_fails(self):
        for saved in [[{'ticker': 'MSFT', 'price': 10}], [{'ticker': 'AAPL', 'price': 0}]]:
            db = self.db()
            with patch.object(db, 'call', return_value=saved):
                with self.assertRaises(pipeline.PipelineError):
                    db.upsert('stock_quotes', [{'ticker': 'AAPL', 'price': 10}], 'ticker')
            self.assertEqual(dict(db.written), {})
            self.assertEqual(dict(db.verified), {})

    def test_successful_post_without_persisted_row_fails(self):
        db = self.db()
        expected = [{'ticker': 'AAPL', 'price': 10}]
        with patch.object(db, 'call', side_effect=[expected, []]):
            with self.assertRaises(pipeline.PipelineError):
                db.upsert('stock_quotes', expected, 'ticker')
        self.assertEqual(db.written['stock_quotes'], 1)
        self.assertEqual(dict(db.verified), {})

    def test_readback_detects_old_data_even_after_successful_post(self):
        db = self.db()
        with patch.object(db, 'call', side_effect=[
                [{'ticker': 'AAPL', 'price': 10}], [{'ticker': 'AAPL', 'price': 9}]]):
            with self.assertRaises(pipeline.PipelineError):
                db.upsert('stock_quotes', [{'ticker': 'AAPL', 'price': 10}], 'ticker')
        self.assertEqual(dict(db.verified), {})

    def test_readback_supports_server_page_caps(self):
        db = self.db()
        rows = [{'ticker': 'AAPL', 'price': 10}, {'ticker': 'MSFT', 'price': 20}]
        with patch.object(db, 'call', side_effect=[rows, rows[:1], rows[1:]]) as call:
            db.upsert('stock_quotes', rows, 'ticker')
        self.assertEqual(db.verified['stock_quotes'], 2)
        self.assertEqual([c.kwargs['params']['offset'] for c in call.call_args_list[1:]], [0, 1])

    def test_timestamp_serialization_and_row_order_do_not_fail_valid_writes(self):
        rows = [{'ticker': 'AAPL', 'updated_at': '2026-11-08T12:00:00+00:00', 'price': 10.0},
                {'ticker': 'MSFT', 'updated_at': '2026-11-08T12:00:00+00:00', 'price': 20.0}]
        returned = [{**row, 'updated_at': '2026-11-08T12:00:00Z', 'id': i} for i, row in enumerate(reversed(rows))]
        confirm_rows(rows, returned, 'ticker,updated_at', 'stock_quotes')

    def test_fetched_rows_are_committed_before_a_slow_symbol_finishes(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = StoredDatabase(str(Path(tmp) / 'saved.sqlite'))
            self.addCleanup(db.connection.close)
            symbols = [f'T{i:02}' for i in range(11)]
            slow_observed_publication = []
            def fetched(symbol, scope, history_range=None):
                if symbol == 'T10':
                    slow_observed_publication.append(db.saved_quotes.wait(3))
                from datetime import datetime, timezone
                chart = {'meta': {'regularMarketPrice': 123.45,
                         'regularMarketTime': datetime.now(timezone.utc).timestamp()}}
                return pipeline.market_rows(symbol, chart, {'marketCap': 1234567}), []
            report = {'symbols': {}, 'errors': [], 'warnings': []}
            with patch.object(pipeline, 'fetch_symbol', side_effect=fetched):
                pipeline.sync_market(db, symbols, 'quotes', 2, report)
            self.assertEqual(slow_observed_publication, [True])
            self.assertTrue(all(row['persisted'] for row in report['symbols'].values()))
            self.assertEqual(db.verified['stock_quotes'], 11)
            # A separate connection sees committed provider values, not merely
            # successful HTTP responses or report counters.
            with sqlite3.connect(db.path) as read:
                quotes = [json.loads(row[0]) for row in read.execute(
                    "SELECT payload FROM saved WHERE collection='stock_quotes'")]
            self.assertEqual(len(quotes), 11)
            self.assertTrue(all(row['price'] == 123.45 for row in quotes))

    def test_failed_later_table_never_marks_symbol_persisted(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = StoredDatabase(str(Path(tmp) / 'saved.sqlite'))
            self.addCleanup(db.connection.close)
            db.fail_table = 'stock_details'
            from datetime import datetime, timezone
            rows = pipeline.market_rows('AAPL', {'meta': {
                'regularMarketPrice': 10, 'regularMarketTime': datetime.now(timezone.utc).timestamp()}}, {})
            report = {'symbols': {}, 'errors': [], 'warnings': []}
            with patch.object(pipeline, 'fetch_symbol', return_value=(rows, [])):
                with self.assertRaises(pipeline.PipelineError):
                    pipeline.sync_market(db, ['AAPL'], 'quotes', 1, report)
            self.assertFalse(report['symbols']['AAPL']['persisted'])
            self.assertEqual(db.verified['stock_quotes'], 1)

    def test_finalization_rejects_fetch_only_or_dry_run_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'market-sync-report-0.json'
            for persisted, dry_run in [(False, False), (True, True)]:
                path.write_text(json.dumps({'status': 'passed', 'errors': [], 'dry_run': dry_run,
                    'requested_symbols': 1, 'symbols': {'AAPL': {'persisted': persisted}}}))
                with self.assertRaises(ValueError):
                    market_selection.validated_symbols(['AAPL'], Path(tmp))


if __name__ == '__main__':
    unittest.main()
