"""Offline tests for per-instrument detail sections."""
import json
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
import build_market_universe as builder
import market_details as details


class FakeTicker:
    news = [{'content': {'title': 'Headline', 'canonicalUrl': {'url': 'https://e.test/a'},
                         'provider': {'displayName': 'Wire'}, 'pubDate': '2026-01-01T00:00:00Z'}}, {'title': ''}]
    options = ('2026-12-18',)

    @property
    def recommendations(self):
        raise RuntimeError('https://secret.test?key=1')


class DetailTests(unittest.TestCase):
    def test_clean_is_strict_json(self):
        value = details.clean({'a': float('nan'), 'b': [math.inf, 1.5]})
        self.assertEqual(json.loads(json.dumps(value, allow_nan=False)), {'a': None, 'b': [None, 1.5]})

    def test_news_requires_title_and_link(self):
        items = details.news_items(FakeTicker.news)
        self.assertEqual([i['title'] for i in items], ['Headline'])
        self.assertEqual(items[0]['publisher'], 'Wire')

    def test_one_failing_section_does_not_discard_the_others(self):
        sections = {'news': lambda t: details.news_items(t.news), 'recommendations': lambda t: t.recommendations}
        detail, availability, warnings = details.fetch_sections(FakeTicker(), sections)
        self.assertIn('news', detail)
        self.assertNotIn('recommendations', detail)
        self.assertFalse(availability['recommendations']['available'])
        self.assertEqual(warnings, ['recommendations: RuntimeError'])
        self.assertNotIn('secret', json.dumps(availability))

    def test_empty_sections_are_reported_unavailable(self):
        detail, availability, _ = details.fetch_sections(FakeTicker(), {'news': lambda t: []})
        self.assertEqual(detail, {})
        self.assertEqual(availability['news'], {'available': False, 'count': 0})


class UniverseFileTests(unittest.TestCase):
    def test_symbol_mapping(self):
        self.assertEqual(builder.yahoo_symbol('BRK/B'), 'BRK-B')
        self.assertEqual(builder.yahoo_symbol('LEN.B'), 'LEN-B')
        self.assertEqual(builder.yahoo_symbol('OXY.WS'), 'OXY-WT')
        self.assertEqual(builder.parse_market_cap('$5.18T'), 5_180_000_000_000)
        self.assertEqual(builder.parse_market_cap('$17.44M'), 17_440_000)

    def test_generated_json_matches_the_markdown(self):
        generated = json.loads(builder.TARGET.read_text())
        self.assertEqual(generated, builder.parse(builder.SOURCE.read_text(encoding='utf-8')))
        self.assertEqual(len(generated), 5000)
        self.assertEqual([r['rank'] for r in generated], list(range(1, 5001)))


if __name__ == '__main__':
    unittest.main()
