#!/usr/bin/env python3
"""Generate public AdSense verification and seller records, never credentials."""
import re
from pathlib import Path

START = '<!-- ADSENSE_VERIFICATION_START -->'
END = '<!-- ADSENSE_VERIFICATION_END -->'


def publisher_from_settings(settings):
    publisher = settings.get('ADSENSE_PUBLISHER_ID', '').strip().strip('\"\'')
    if publisher and not re.fullmatch(r'ca-pub-\d{16}', publisher):
        raise ValueError('ADSENSE_PUBLISHER_ID must be ca-pub- followed by 16 digits')
    return publisher


def prepare_adsense(root, settings):
    publisher = publisher_from_settings(settings)
    index = root / 'web/index.html'
    html = index.read_text()
    if START not in html or END not in html:
        raise ValueError('Missing AdSense verification markers in web/index.html')
    meta = f'\n  <meta name="google-adsense-account" content="{publisher}">\n  ' if publisher else '\n  '
    html = re.sub(re.escape(START) + r'.*?' + re.escape(END), START + meta + END,
                  html, count=1, flags=re.S)
    index.write_text(html)
    lines = ['# alphajournal authorized advertising sellers.']
    if publisher:
        lines.append(f'google.com, {publisher.removeprefix("ca-")}, DIRECT, f08c47fec0942fa0')
    else:
        lines.append('# No advertising seller is configured yet.')
    (root / 'web/ads.txt').write_text('\n'.join(lines) + '\n')
    return bool(publisher)


if __name__ == '__main__':
    import os
    from prepare_client_config import export_public_settings
    root = Path(__file__).resolve().parent.parent
    source = root / '.env'
    raw = export_public_settings(source.read_text() if source.exists() else '', os.environ)
    settings = dict(line.split('=', 1) for line in raw.splitlines() if '=' in line and not line.startswith('#'))
    ready = prepare_adsense(root, settings)
    print('AdSense verification configured.' if ready else 'AdSense remains unconfigured; no placeholder seller published.')
