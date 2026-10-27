"""Build a local review gallery from the scripted Flutter captures."""
from html import escape
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
output = root / 'artifacts/admin-affiliate-design'
images = sorted(output.glob('*.png'))
log = (output / 'tests.log').read_text() if (output / 'tests.log').exists() else ''
counts = re.findall(r'\+(\d+): All tests passed!', log)
manifest = {
    'screenshots': len(images),
    'tests_passed': int(counts[-1]) if counts else None,
    'data': 'Local preview and fake repository data; no production mutations.',
    'viewports': ['320px at 1.5x text', '768px', '1440px', '520px pane inside 1440px at 1.3x text in dark mode'],
    'images': [path.name for path in images],
}
(output / 'verification.json').write_text(json.dumps(manifest, indent=2) + '\n')
items = '\n'.join(f'<a href="{escape(path.name)}"><img loading="lazy" src="{escape(path.name)}" alt="{escape(path.stem)}"><span>{escape(path.stem.replace("-", " "))}</span></a>' for path in images)
(output / 'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>TradeX workspace review</title><style>body{font:16px system-ui;margin:32px;background:#f5f5f4;color:#232120}h1{font-size:28px}p{max-width:75ch}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px}[hidden]{display:none!important}a{display:block;background:white;color:inherit;border:1px solid #ddd;border-radius:12px;text-decoration:none;overflow:hidden}img{width:100%;height:320px;object-fit:contain;object-position:top;background:#eee}span{display:block;padding:14px}input{font:inherit;padding:12px;margin:12px 0 24px;width:min(480px,90%)}</style><h1>Admin & affiliate workspace review</h1><p>Scripted Flutter captures of pages, subpages, forms and dialogs. Uses local preview data. Includes phone, tablet, desktop, narrow panes, larger text and keyboard insets.</p><p>Run <code>bash scripts/verify_admin_affiliate_ui.sh</code> to regenerate. See <a href="verification.json">verification details</a>.</p><input id="filter" placeholder="Filter by page or viewport" aria-label="Filter screenshots"><main>''' + items + '''</main><script>document.querySelector('#filter').addEventListener('input',e=>{for(const a of document.querySelectorAll('main a'))a.hidden=!a.textContent.toLowerCase().includes(e.target.value.toLowerCase())})</script></html>''')
print(f'Created review gallery with {len(images)} screenshots.')
