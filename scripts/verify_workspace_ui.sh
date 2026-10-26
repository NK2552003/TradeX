#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
flutter analyze --no-pub
flutter test \
  test/core/workspace_card_layout_test.dart \
  test/features/ai_assistant/ai_assistant_redesign_test.dart \
  test/features/admin_console \
  test/features/affiliate_program
