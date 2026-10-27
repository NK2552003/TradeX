#!/usr/bin/env bash
# Scripted layout, interaction, connection and component regressions.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
report_dir="artifacts/admin-affiliate-design"
mkdir -p "$report_dir"
flutter analyze --no-pub 2>&1 | tee "$report_dir/analyze.log"
flutter test --no-pub --dart-define=CAPTURE_WORKSPACE_UI=true \
  test/features/admin_console \
  test/features/affiliate_program \
  test/core/workspace_table_flow_test.dart \
  test/core/workspace_card_layout_test.dart \
  test/core/flutter-ui/reusable_components_test.dart \
  test/features/ai_assistant/ai_assistant_redesign_test.dart \
  test/features/messages/messages_redesign_test.dart \
  2>&1 | tee "$report_dir/tests.log"
git diff --check
python3 scripts/workspace_ui_gallery.py
