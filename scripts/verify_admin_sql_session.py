#!/usr/bin/env python3
"""Run the repository's rollback SQL checks using an existing Supabase tab.

Authentication stays inside Chrome. No browser session credentials are printed
or copied to disk. Each allowed SQL file creates temporary verification state
and ends with ROLLBACK.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys
import time
import uuid

from chrome_admin_session import chrome_pid, evaluate


ROOT = Path(__file__).resolve().parent.parent
CHECKS = {
    'readback': 'admin_live_readback.sql',
    'controls': 'admin_user_management.sql',
    'deletion-consent': 'admin_deletion_consent_live.sql',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('check', choices=CHECKS)
    parser.add_argument('--tab-id', required=True, help='Existing Supabase SQL tab ID.')
    parser.add_argument('--output', type=Path, help='Where to save non-sensitive check results.')
    args = parser.parse_args()
    pid = chrome_pid()
    url = evaluate(pid, args.tab_id, 'location.href')
    match = re.match(r'https://supabase\.com/dashboard/project/([a-z0-9]+)/sql/', url)
    if not match:
        raise RuntimeError('Choose an existing Supabase SQL Editor tab.')
    project = match.group(1)
    path = ROOT / 'database/tests' / CHECKS[args.check]
    sql = path.read_text()
    if not sql.rstrip().endswith('ROLLBACK;') or re.search(r'^COMMIT\s*;', sql, re.M | re.I):
        raise RuntimeError('Verification must end with ROLLBACK and contain no COMMIT.')
    node_id = 'tradex-admin-check-' + uuid.uuid4().hex
    start = '''(() => {
      const session=JSON.parse(localStorage.getItem('supabase.dashboard.auth.token')||'{}');
      if(!session.access_token)throw new Error('Sign in to the Supabase dashboard first.');
      const node=document.createElement('script');node.type='application/json';
      node.id=NODE_ID;node.textContent=JSON.stringify({pending:true});
      document.documentElement.appendChild(node);
      (async()=>{
        try {
          const response=await fetch(ENDPOINT,{
            method:'POST',
            headers:{'Content-Type':'application/json',Authorization:'Bearer '+session.access_token},
            body:JSON.stringify({query:SQL_TEXT,read_only:false}),
            signal:AbortSignal.timeout(40000)
          });
          node.textContent=JSON.stringify({status:response.status,result:await response.json()});
        } catch(error) {
          node.textContent=JSON.stringify({error:String(error)});
        }
      })();
      return JSON.stringify({submitted:true});
    })()'''
    start = start.replace('NODE_ID', json.dumps(node_id)).replace(
        'ENDPOINT', json.dumps(f'https://api.supabase.com/v1/projects/{project}/database/query')
    ).replace('SQL_TEXT', json.dumps(sql))
    evaluate(pid, args.tab_id, start)
    result = None
    try:
        deadline = time.monotonic() + 50
        while time.monotonic() < deadline:
            result = evaluate(
                pid, args.tab_id,
                f"document.getElementById({json.dumps(node_id)})?.textContent || 'null'",
            )
            if isinstance(result, dict) and not result.get('pending'):
                break
            time.sleep(0.5)
        else:
            raise RuntimeError('SQL verification timed out; inspect the dashboard before retrying.')
        if result.get('error') or result.get('status') not in (200, 201):
            raise RuntimeError(json.dumps(result))
        rows = result.get('result')
        if not isinstance(rows, list) or not rows:
            raise RuntimeError('SQL verification returned no check results.')
        for row in rows:
            value = str(row.get('result', ''))
            if row.get('check_name') == 'Live user count':
                if not value.isdigit():
                    raise RuntimeError('Invalid live account count.')
            elif 'PASS' not in value:
                raise RuntimeError('Verification failed: ' + json.dumps(row))
        report = {
            'checked_at': datetime.now(timezone.utc).isoformat(),
            'project': project,
            'source': 'Existing Chrome Supabase session; authenticated Management API',
            'sql_file': str(path.relative_to(ROOT)),
            'sql_sha256': hashlib.sha256(sql.encode()).hexdigest(),
            'transaction': 'rolled back',
            'checks_passed': len(rows),
            'checks': rows,
        }
        output = args.output or ROOT / 'artifacts/admin-deployment' / f'live-{args.check}-checks.json'
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps({'checks_passed': len(rows), 'report': str(output)}))
    finally:
        evaluate(pid, args.tab_id, f"document.getElementById({json.dumps(node_id)})?.remove(); 'cleared'")


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
