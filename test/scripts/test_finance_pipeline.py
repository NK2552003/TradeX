"""Offline regression checks for the downloaded kits' integration."""
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import asset_runtime
import fetch_finance_data as core
import screeners
import pandas as pd

class FinancePipelineTests(unittest.TestCase):
    def test_news_retains_ticker_links_and_latest_metadata(self):
        merged = asset_runtime.merge_news(
            [{'link': 'https://example.test/a', 'title': 'Earlier', 'ticker': 'AAPL', 'related_tickers': ['AAPL']}],
            [{'link': 'https://example.test/a', 'title': 'Latest', 'ticker': 'MSFT', 'related_tickers': ['MSFT']}])
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]['related_tickers'], ['AAPL', 'MSFT'])
        self.assertEqual(merged[0]['title'], 'Latest')

    def test_nonfinite_values_are_strict_json_and_atomic(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'data.json'
            asset_runtime.write_json(path, {'missing': float('nan'), 'nested': [float('inf'), 3]})
            self.assertEqual(asset_runtime.read_json(path, {}), {'missing': None, 'nested': [None, 3]})
            self.assertFalse(path.with_suffix('.json.tmp').exists())

    def test_single_and_multi_ticker_download_shapes(self):
        dates = pd.date_range('2026-09-01', periods=2)
        frame = pd.DataFrame({'Open': [10., 11.], 'High': [12., 13.], 'Low': [9., 10.], 'Close': [11., 12.], 'Volume': [100, 200]}, index=dates)
        for symbols, data in [(['AAPL'], frame), (['AAPL','MSFT'], pd.concat({'AAPL': frame, 'MSFT': frame}, axis=1))]:
            with patch.object(core.yf, 'download', return_value=data):
                quotes, histories = core.fetch_batch_quotes_and_history(symbols)
                self.assertEqual(set(quotes), set(symbols))
                for symbol in symbols:
                    self.assertEqual(quotes[symbol]['price'], 12.)
                    self.assertEqual(len(histories[symbol]['data']), 2)

    def test_invalid_ohlc_rows_are_skipped(self):
        frame = pd.DataFrame({'Open': [float('nan')], 'High': [12.], 'Low': [9.], 'Close': [11.], 'Volume': [100]}, index=pd.date_range('2026-09-01', periods=1))
        with patch.object(core.yf, 'download', return_value=frame):
            quotes, histories = core.fetch_batch_quotes_and_history(['AAPL'])
            self.assertEqual(quotes, {})
            self.assertEqual(histories, {})

    def test_predefined_screen_keeps_app_filename(self):
        response = {'quotes': [{'symbol': 'AAPL'}]}
        with patch.object(screeners.yf, 'screen', return_value=response), patch.object(screeners, 'save') as save:
            screeners.run_predefined('day_gainers', label='top_gainers')
            save.assert_called_once_with('top_gainers', response)

if __name__ == '__main__':
    unittest.main()
