"""Bound the refresh universe before any provider calls; keep stored history."""
import json
import math

from market_universe import RETIRED_SYMBOLS, TARGET_TICKERS

MAX_SYMBOLS = 5000


def supported_symbol(value):
    symbol = str(value or '').strip().upper()
    # Exchange unit/warrant notation is not a Yahoo equity symbol. Do not
    # repeatedly request known unsupported listings such as AAC.U / AAC.W.
    return symbol and symbol not in RETIRED_SYMBOLS and not symbol.endswith(('.U', '.W', '.WS'))


def select_symbols(stored, limit=MAX_SYMBOLS):
    """Curated benchmarks first, then descending reported trading volume.

    Volume is a transparent popularity proxy, not a market-cap ranking. Ties
    use the symbol for repeatable partitions across all CI workers.
    """
    def volume(row):
        value = row.get('volume')
        return value if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and value > 0 else 0

    ranked = sorted(stored, key=lambda row: (-volume(row), row['ticker']))
    symbols = dict.fromkeys(s for s in TARGET_TICKERS if supported_symbol(s))
    for row in ranked:
        symbol = str(row['ticker']).strip().upper()
        if supported_symbol(symbol) and volume(row):
            symbols[symbol] = None
    return list(symbols)[:min(limit, MAX_SYMBOLS)]


def validated_symbols(symbols, directory):
    """Only finalize complete, successful partitions of the frozen manifest."""
    seen, discarded = set(), set()
    for path in sorted(directory.glob('market-sync-report-*.json')):
        report = json.loads(path.read_text())
        if report.get('status') != 'passed' or report.get('errors'):
            raise ValueError('Market partition failed or was interrupted')
        partition = set(report['symbols'])
        if seen & partition or len(partition) != report['requested_symbols']:
            raise ValueError('Duplicate or incomplete market partition')
        if report.get('dry_run') is not False:
            raise ValueError('Dry-run reports cannot confirm database publication')
        for symbol, result in report['symbols'].items():
            if symbol not in report.get('discarded_symbols', {}) and result.get('persisted') is not True:
                raise ValueError('Partition contains unverified database writes')
        seen.update(partition)
        discarded.update(report.get('discarded_symbols', {}))
    if seen != set(symbols) or not discarded <= seen:
        raise ValueError('Partition reports do not cover the selected universe')
    valid = [symbol for symbol in symbols if symbol not in discarded]
    if not valid:
        raise ValueError('No valid market symbols remain')
    return valid
