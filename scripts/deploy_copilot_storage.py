#!/usr/bin/env python3
"""Apply only the additive hosted-copilot table, using a scoped Management token.

This deliberately does not push the repository's unrelated migration history.
Existing Edge Function provider secrets are neither read nor modified.
"""
import argparse
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / 'supabase/migrations/20261108065544_copilot_workspaces.sql'


def deploy(project, token):
    if not re.fullmatch('[a-z]{20}', project):
        raise ValueError('Use the 20-character Supabase project reference')
    if not token:
        raise ValueError('Set SUPABASE_ACCESS_TOKEN to a scoped token with database query permission')

    def query(sql):
        request = urllib.request.Request(
            f'https://api.supabase.com/v1/projects/{project}/database/query',
            method='POST', data=json.dumps({'query': sql}).encode(),
            headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError(f'Supabase deployment returned HTTP {error.code}; check token permissions and project reference') from None
        except (OSError, ValueError):
            raise RuntimeError('Supabase deployment could not be confirmed; retry the idempotent deployment') from None

    query('BEGIN;\n' + MIGRATION.read_text() + "\nNOTIFY pgrst, 'reload schema';\nCOMMIT;")
    rows = query("""SELECT c.relrowsecurity AS rls,
      (has_table_privilege('authenticated', 'public.copilot_workspaces', 'SELECT')
       AND has_table_privilege('authenticated', 'public.copilot_workspaces', 'INSERT')
       AND has_table_privilege('authenticated', 'public.copilot_workspaces', 'UPDATE')
       AND has_table_privilege('authenticated', 'public.copilot_workspaces', 'DELETE')) AS authenticated_access,
      has_table_privilege('anon', 'public.copilot_workspaces', 'SELECT') AS anonymous_access,
      EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='copilot_workspaces'
              AND policyname='copilot_workspace_owner' AND qual IS NOT NULL AND with_check IS NOT NULL) AS owner_policy
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname='copilot_workspaces'""")
    if not isinstance(rows, list) or len(rows) != 1 or rows[0] != {
            'rls': True, 'authenticated_access': True, 'anonymous_access': False, 'owner_policy': True}:
        raise RuntimeError('Copilot storage was created but access-policy verification failed')
    print('Copilot storage deployed and access policy verified. Existing Edge secrets were unchanged.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-ref', required=True)
    args = parser.parse_args()
    try:
        deploy(args.project_ref, os.getenv('SUPABASE_ACCESS_TOKEN', ''))
    except (ValueError, RuntimeError) as error:
        parser.exit(1, f'{error}\n')
