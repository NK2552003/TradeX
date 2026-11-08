#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Node 22.18+ supports the TypeScript module used by the Edge Function tests.
node --test test/features/copilot/ai_gateway_search_test.mjs
flutter test \
  test/features/copilot/supabase_copilot_api_test.dart \
  test/features/community/community_post_route_echo_test.dart \
  test/features/community/post_open_race_test.dart \
  test/features/community/desktop_post_click_navigation_test.dart \
  test/features/customer_frontend/auth_splash_test.dart \
  test/features/customer_frontend/account_startup_test.dart \
  test/features/market_data/community_movers_panel_test.dart
