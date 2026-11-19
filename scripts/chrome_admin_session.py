#!/usr/bin/env python3
"""Run administration checks in the user's already-open macOS Chrome session.

Unlike a name-based AppleScript target, ScriptingBridge selects Chrome by PID.
This avoids accidentally using Flutter's separate, unauthenticated Chrome.
No profile, cookie, or credential files are read and no browser is launched.
"""

import argparse
import json
from pathlib import Path
import subprocess
import sys


BRIDGE = r"""
ObjC.import('ScriptingBridge');
let failure = null;
ObjC.registerSubclass({
  name: 'AlphaJournalChromeDelegate', superclass: 'NSObject',
  methods: {'eventDidFail:withError:': {
    types: ['id', ['void *', 'id']],
    implementation: function(event, error) {
      failure = ObjC.deepUnwrap(error.userInfo);
      return null;
    }
  }}
});
const delegate = $.AlphaJournalChromeDelegate.alloc.init;
const app = $.SBApplication.applicationWithProcessIdentifier(TASK_PID);
app.delegate = delegate;
const windows = app.valueForKey('windows');
const inventory = [];
let selected = null;
for (let i = 0; i < windows.count; i++) {
  const window = windows.objectAtIndex(i);
  const tabs = window.valueForKey('tabs');
  for (let j = 0; j < tabs.count; j++) {
    const tab = tabs.objectAtIndex(j);
    const id = ObjC.unwrap(tab.valueForKey('id'));
    const url = ObjC.unwrap(tab.valueForKey('URL'));
    if (/^https:\/\/supabase.com\/dashboard\//.test(url) ||
        /^http:\/\/(localhost|127\.0\.0\.1)(:|\/)/.test(url)) {
      inventory.push({id, url, title: ObjC.unwrap(tab.valueForKey('title'))});
      if (id === TASK_TAB) selected = tab;
    }
  }
}
let output;
if (TASK_SCRIPT === null) {
  output = {pid: TASK_PID, tabs: inventory, error: failure};
} else if (!selected) {
  output = {error: 'Choose an existing Supabase or local application tab from list.'};
} else {
  const result = selected.performSelectorWithObject('executeJavascript:', $(TASK_SCRIPT));
  output = {result: ObjC.unwrap(result), error: failure};
}
JSON.stringify(output);
"""

INSPECT = """JSON.stringify({
  title: document.title,
  url: location.href,
  text: document.body.innerText.slice(0, 22000),
  controls: Array.from(document.querySelectorAll('button,input,textarea,a'))
    .map(n => ({tag:n.tagName, role:n.getAttribute('role'),
      label:n.getAttribute('aria-label'), text:(n.innerText || '').slice(0,120),
      placeholder:n.getAttribute('placeholder'), href:n.getAttribute('href'),
      disabled:n.disabled || false}))
})"""


def chrome_pid():
    processes = subprocess.run(
        ['ps', '-Ao', 'pid=,command='], check=True, capture_output=True, text=True
    )
    executable = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
    for line in processes.stdout.splitlines():
        parts = line.strip().split(maxsplit=1)
        if len(parts) == 2 and parts[1] == executable:
            return int(parts[0])
    raise RuntimeError('The regular Google Chrome session is not running.')


def evaluate(pid, tab_id, source):
    """Evaluate a script in one explicit tab, propagating Chrome errors."""
    parameters = (
        f'const TASK_PID = {pid};\n'
        f'const TASK_TAB = {json.dumps(tab_id)};\n'
        f'const TASK_SCRIPT = {json.dumps(source)};\n'
    )
    command = subprocess.run(
        ['osascript', '-l', 'JavaScript'], input=parameters + BRIDGE,
        text=True, capture_output=True, timeout=45, check=True,
    )
    output = json.loads(command.stdout)
    error = output.get('error')
    if error:
        if isinstance(error, dict):
            error = error.get('ErrorString') or error
        raise RuntimeError(str(error))
    value = output.get('result', output)
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            pass
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['list', 'inspect', 'run-js'])
    parser.add_argument('--pid', type=int, help='Existing Chrome PID; auto-detected by default.')
    parser.add_argument('--tab-id', help='Tab ID returned by list.')
    parser.add_argument('--file', type=Path, help='JavaScript file for run-js; never a credential file.')
    args = parser.parse_args()
    if args.action != 'list' and not args.tab_id:
        parser.error('--tab-id is required for inspect and run-js')
    if args.action == 'run-js' and not args.file:
        parser.error('--file is required for run-js')
    source = None
    if args.action == 'inspect':
        source = INSPECT
    elif args.action == 'run-js':
        source = args.file.read_text()
    pid = args.pid or chrome_pid()
    value = evaluate(pid, args.tab_id, source)
    print(json.dumps(value, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
