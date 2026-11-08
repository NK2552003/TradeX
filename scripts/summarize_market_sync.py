#!/usr/bin/env python3
"""Bound GitHub summaries; detailed per-symbol results remain in artifacts."""
import json
import os
from pathlib import Path
import sys


def summarize(paths):
    lines = []
    for filename in paths:
        path = Path(filename)
        if not path.exists():
            lines.append('Market sync did not produce a report. See the failed step.')
            continue
        report = json.loads(path.read_text())
        status = report['status']
        if status == 'running':
            status = 'interrupted (partial checkpoint; not a successful publication)'
        lines.extend([f'## Market sync: {status}', '',
                      f"Scope: {report['scope']}; selected symbols: {report.get('requested_symbols', 0)}", '',
                      f"Discarded listings: {len(report.get('discarded_symbols', {}))}",
                      f"Validated: {json.dumps(report.get('market', {}))}",
                      f"Confirmed writes: {json.dumps(report.get('confirmed_writes', {}))}",
                      f"Read-back verified writes: {json.dumps(report.get('verified_writes', {}))}",
                      f"Persisted symbols: {sum(v.get('persisted') is True for v in report['symbols'].values())}", ''])
        issues = report['errors'] + report['warnings']
        issues += [f'{symbol}: discarded ({reason})' for symbol, reason in report.get('discarded_symbols', {}).items()]
        issues += [f'{s}: {w}' for s, result in report['symbols'].items() for w in result['warnings']]
        lines.extend(f'- {issue}' for issue in issues[:100])
        if len(issues) > 100:
            lines.append(f'{len(issues) - 100} additional issues are in the report artifact.')
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    summary = summarize(sys.argv[1:])
    if os.getenv('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as output:
            output.write(summary)
    else:
        print(summary)
