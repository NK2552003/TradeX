"""Execute the asset contract/seeds in an isolated temporary PostgreSQL cluster."""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def main():
    for binary in ['initdb', 'pg_ctl', 'psql']:
        if not shutil.which(binary):
            raise RuntimeError(f'{binary} is required for SQL integration validation')
    with tempfile.TemporaryDirectory(prefix='alphajournal-sql-') as temporary:
        base = Path(temporary)
        cluster = base / 'cluster'
        env = {**os.environ, 'LC_ALL': 'C'}
        def command(args, **kwargs):
            result = subprocess.run(args, env=env, capture_output=True, text=True, **kwargs)
            if result.returncode:
                raise RuntimeError(result.stderr[-2000:])
            return result
        command(['initdb', '-D', str(cluster), '-A', 'trust', '--no-locale', '-E', 'UTF8'])
        started = False
        try:
            command(['pg_ctl', '-D', str(cluster), '-l', str(base / 'postgres.log'), '-o', f"-k {base} -p 55439 -c listen_addresses=''", '-w', 'start'])
            started = True
            args = ['psql', '-h', str(base), '-p', '55439', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-At']
            def query(text):
                return command(args, input=text).stdout.strip()
            query('CREATE ROLE anon; CREATE ROLE authenticated;')
            schema = (ROOT / 'database/schema.sql').read_text()
            start = schema.index('CREATE TABLE IF NOT EXISTS tickers (')
            end = schema.index('COMMIT;', start)
            query(schema[start:end])
            for migration in ['023_public_site_and_market_assets.sql', '024_market_screener_snapshots.sql']:
                query((ROOT / 'database/migrations' / migration).read_text())
            for _ in range(2):  # A repeated export must not duplicate articles or instruments.
                for name in ['03_public_site.sql', '04_market_assets.sql']:
                    query((ROOT / 'database/seeds' / name).read_text())
            import json
            manifest = json.loads((ROOT / 'assets/data/manifest.json').read_text())
            assert int(query('SELECT count(*) FROM stock_quotes;')) == manifest['quote_count']
            assert int(query('SELECT count(*) FROM market_screener_snapshots;')) == manifest['screener_category_count']
            assert int(query('SELECT count(*) FROM stock_details;')) == manifest['detail_count']
            assert int(query('SELECT count(*) FROM news_articles;')) == manifest['article_count']
            assert query("SELECT jsonb_array_length(catalogue->'plans') FROM pricing_catalogues WHERE id = 'default';") == '3'
            assert query("SELECT has_table_privilege('anon', 'pricing_catalogues', 'INSERT');") == 'f'
            query("INSERT INTO public_site_pages(id,content,published) VALUES('draft','{}',false);")
            assert query('SET ROLE anon; SELECT count(*) FROM public_site_pages;').splitlines()[-1] == '1'
            print(f"SQL integration passed: {manifest['detail_count']} instruments, {manifest['article_count']} articles, idempotent seeds, published-only public reads, no anonymous writes.")
        finally:
            if started:
                command(['pg_ctl', '-D', str(cluster), '-m', 'fast', '-w', 'stop'])

if __name__ == '__main__':
    main()
