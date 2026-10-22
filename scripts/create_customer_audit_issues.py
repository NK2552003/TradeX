#!/usr/bin/env python3
"""Publish customer audit drafts with existing labels and resumable deduplication."""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
DRAFTS = ROOT / 'customer_side/github_issues'


def gh(*args):
    result = subprocess.run(
        ['gh', *args], text=True, capture_output=True, check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result.stdout


def labels_for(issue, available):
    candidates = ['bug', issue['side'], f"area: {issue['side']}"]
    slug = issue['key'].removeprefix(issue['side'] + '-')
    candidates += [slug, slug.replace('_', '-'), slug.replace('_', ' ')]
    if issue['side'] == 'frontend':
        candidates += ['ui', 'ux', 'ui/ux']
    if slug in ('auth', 'rls_and_security', 'affiliate_program'):
        candidates += ['security']
    return sorted({available[c.lower()] for c in candidates if c.lower() in available})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', default='NK2552003/TradeX')
    parser.add_argument('--publish', action='store_true', help='Create the issues on GitHub')
    args = parser.parse_args()
    issues = json.loads((DRAFTS / 'issues.json').read_text())
    if not args.publish:
        print(f'{len(issues)} drafts ready for {args.repo}; no remote changes made.')
        for issue in issues:
            print(issue['title'])
        return

    gh('auth', 'status', '--hostname', 'github.com')
    repo = json.loads(gh('repo', 'view', args.repo, '--json', 'hasIssuesEnabled,isPrivate'))
    if not repo['hasIssuesEnabled']:
        raise RuntimeError('Issues are disabled for this repository.')
    labels = json.loads(gh('label', 'list', '--repo', args.repo, '--limit', '1000', '--json', 'name'))
    available = {item['name'].lower(): item['name'] for item in labels}
    pages = json.loads(gh('api', '--paginate', '--slurp', f'repos/{args.repo}/issues?state=all&per_page=100'))
    existing = {
        item['title']: item for page in pages for item in page if 'pull_request' not in item
    }
    manifest_path = DRAFTS / 'created.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    for issue in issues:
        # An exact title or a previously recorded URL makes reruns safe after interruption.
        prior = existing.get(issue['title'])
        if prior:
            url = prior['html_url']
            status = 'existing'
        elif issue['key'] in manifest:
            url = manifest[issue['key']]['url']
            gh('issue', 'view', url, '--json', 'url')
            status = 'recorded'
        else:
            with tempfile.TemporaryDirectory(prefix='tradex-issue-') as temporary:
                body_file = Path(temporary) / 'body.md'
                body_file.write_text(issue['body'])
                command = ['issue', 'create', '--repo', args.repo, '--title', issue['title'], '--body-file', str(body_file)]
                for label in labels_for(issue, available):
                    command += ['--label', label]
                url = gh(*command).strip()
            status = 'created'
        verified = json.loads(gh('issue', 'view', url, '--json', 'number,title,url,labels'))
        if verified['title'] != issue['title']:
            raise RuntimeError(f'Unexpected issue title at {url}')
        manifest[issue['key']] = verified
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
        print(f"{status}: #{verified['number']} {issue['title']} {url}", flush=True)

    lines = ['# Customer-side audit issues', '', f'Repository: {args.repo}', '',
             '| Area | Issue | Labels |', '| --- | --- | --- |']
    for issue in issues:
        saved = manifest[issue['key']]
        labels_text = ', '.join(label['name'] for label in saved['labels']) or 'No matching existing labels'
        lines.append(f"| {issue['key']} | [#{saved['number']}: {saved['title']}]({saved['url']}) | {labels_text} |")
    (DRAFTS / 'README.md').write_text('\n'.join(lines) + '\n')
    print(f'Verified {len(issues)} issues. Index: {DRAFTS / "README.md"}')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError, ValueError) as error:
        raise SystemExit(str(error)) from error
