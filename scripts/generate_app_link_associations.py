#!/usr/bin/env python3
"""Generate website associations from real app signing identifiers, without secrets.

No defaults for domains, Team IDs or fingerprints: existing example bundle IDs
are development identifiers. This writes public website files only; native
verified-link entitlements must be enabled for the same domain at release time.
"""
import argparse
import json
from pathlib import Path
import re


def associations(domain, package, fingerprints, team_id=None, bundle=None):
    host = domain.strip().lower().encode('idna').decode('ascii')
    if not re.fullmatch(r'(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}', host):
        raise ValueError('Use a bare domain name without a URL scheme, path or port.')
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+', package):
        raise ValueError('Invalid Android application ID.')
    if not fingerprints:
        raise ValueError('At least one real signing SHA-256 fingerprint is required.')
    for fingerprint in fingerprints:
        if not re.fullmatch(r'(?:[A-Fa-f0-9]{2}:){31}[A-Fa-f0-9]{2}', fingerprint):
            raise ValueError('Each SHA-256 fingerprint must contain 32 colon-separated hex bytes.')
    android = [{'relation': ['delegate_permission/common.handle_all_urls'], 'target': {'namespace': 'android_app', 'package_name': package, 'sha256_cert_fingerprints': sorted({f.upper() for f in fingerprints})}}]
    if bool(team_id) != bool(bundle):
        raise ValueError('Provide both Apple Team ID and iOS bundle ID, or omit both.')
    apple = None
    if team_id:
        if not re.fullmatch(r'[A-Z0-9]{10}', team_id) or not bundle:
            raise ValueError('Apple links require a real 10-character Team ID and bundle ID.')
        if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', bundle):
            raise ValueError('Invalid iOS bundle identifier.')
        apple = {'applinks': {'apps': [], 'details': [{'appID': f'{team_id}.{bundle}', 'paths': ['/notes/*', '/journal/*', '/strategies/*', '/community/post/*', '/market/*', '/messages/*']}]}}
    return host, android, apple


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--domain', required=True)
    parser.add_argument('--android-package', required=True)
    parser.add_argument('--android-sha256', action='append', required=True)
    parser.add_argument('--apple-team-id')
    parser.add_argument('--ios-bundle-id')
    parser.add_argument('--output', type=Path, default=Path('build/app-link-associations'))
    args = parser.parse_args()
    try:
        host, android, apple = associations(args.domain, args.android_package, args.android_sha256, args.apple_team_id, args.ios_bundle_id)
    except ValueError as error:
        parser.error(str(error))
    target = args.output / '.well-known'
    target.mkdir(parents=True, exist_ok=True)
    (target / 'assetlinks.json').write_text(json.dumps(android, indent=2) + '\n')
    if apple is not None:
        (target / 'apple-app-site-association').write_text(json.dumps(apple, indent=2) + '\n')
    else:
        (target / 'apple-app-site-association').unlink(missing_ok=True)
    print(f'Generated public association files for {host} in {target}.')
    print('Serve them over HTTPS without redirects. Enable matching Android intent filters and iOS Associated Domains for the signed release.')


if __name__ == '__main__':
    main()
