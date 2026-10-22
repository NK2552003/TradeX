#!/usr/bin/env bash
# Re-run the complete frontend regression suite, including viewport/back/data-policy checks.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
report_dir="$repo_root/customer_side/frontend_issues/validation"
mkdir -p "$report_dir"
flutter analyze 2>&1 | tee "$report_dir/analyze.log"
flutter test 2>&1 | tee "$report_dir/flutter-test.log"
flutter build web --release 2>&1 | tee "$report_dir/web-release-build.log"
git diff --check
