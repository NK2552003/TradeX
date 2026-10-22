#!/usr/bin/env bash
# Explicit customer development entrypoints; sample account data is opt-in.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
mode="${1:-demo}"
port="${2:-8456}"
if [[ ! "$port" =~ ^[0-9]+$ ]] || ((port < 1024 || port > 65535)); then
  echo 'Choose an unprivileged port between 1024 and 65535.' >&2
  exit 2
fi
case "$mode" in
  demo)
    echo "Explicit demo preview: http://127.0.0.1:$port/workspace?preview=customer"
    exec flutter run -d web-server -t lib/main_frontend_preview.dart --web-hostname 127.0.0.1 --web-port "$port"
    ;;
  account)
    echo "Account development: http://127.0.0.1:$port/ (uses configured services; no seeded account data)"
    exec flutter run -d web-server -t lib/main.dart --web-hostname 127.0.0.1 --web-port "$port"
    ;;
  check)
    exec "$repo_root/scripts/verify_customer_frontend.sh"
    ;;
  *)
    echo 'Usage: scripts/dev_customer_frontend.sh [demo|account|check] [port]' >&2
    exit 2
    ;;
esac
