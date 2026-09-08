# Testing strategy: TradeX

## 1. Quality philosophy
Designed for an agile build targeting a 6 to 10 week MVP, testing focuses on areas where regressions carry high impact: data privacy, row-level security enforcement, payment entitlements, and AI infrastructure costs. Rather than pursuing arbitrary overall coverage metrics, tests target code paths handling user records, billing state, and financial calculations.

## 2. Test layers

| Test layer | Framework | Scope and focus |
|---|---|---|
| Unit tests | `flutter test` | Business logic, state notifiers, repositories, DTO mapping, and indicator formatting |
| Widget tests | `flutter test` | UI components in isolation, interaction handlers, and golden tests for core cards |
| Integration tests | `flutter test integration_test/` | End-to-end user flows against local Supabase: authentication, journal creation, posting, social interactions |
| Edge functions | Deno test suite | Verification of `ai-insight`: authentication, rate-limiting rules, cache evaluation, and error handling |
| Database security | `supabase test db` (pgTAP) | Verification of every policy in [API_DATA_MODEL.md](../02-architecture/API_DATA_MODEL.md) across multiple authenticated roles |
| Manual QA | Release checklist | Cross-platform sanity checks across iOS, Android, and web, alongside sandbox in-app purchases |

## 3. Coverage targets
- Domain and business logic: Verify state transitions, repository adapters, and tier-gating logic thoroughly.
- Widget layer: Test stateful and interactive widgets, prioritizing error and empty state presentations.
- Edge functions: Test all HTTP status codes (200 for cached or fresh responses, 429 for rate limits, 401 for unauthenticated requests, 500 for upstream errors).
- Security policies: Validate that every row-level security policy has both an allowed assertion and a denied assertion.

## 4. Row-level security test matrix
Because trade logs are strictly private by default while posts and public strategies allow community read access, all policy modifications require verification across two identities:
1. Row owner: Operations must succeed as expected.
2. Unrelated authenticated user: Operations must fail cleanly with empty result sets or 403 status codes without data leakage.

This validation extends to private versus public strategy visibility, bookmark isolation, and the dual-flag public journal policy (verifying that setting only one of `journal_entries.is_public` or `profiles.public_journals` does not expose records).

Direct messaging requires additional verification scenarios because policies evaluate ownership, subscription tier, and mutual blocking simultaneously:
1. Premium participants: Both users can read and send messages.
2. Uninvolved third party: Querying or inserting into another conversation fails.
3. Free-tier participant: Can read an existing conversation, but sending is rejected on both new and active threads.
4. Mid-conversation downgrade: When a user subscription lapses during a conversation, subsequent messages are rejected even though prior messages succeeded.
5. Blocked relationships: The `are_blocked()` function rejects message insertion in both directions.
6. Read receipts: Verifying that recipients can update `read_at` while `with check` constraints prevent tampering with message text.

Run automated pgTAP tests in `supabase/tests/` through CI, supplemented by manual checks before releases.

## 5. AI edge function validation
Because AI API requests incur external costs and observe tier limits, tests explicitly verify:
- Free tier requests reject immediately with status 429.
- Premium tier requests succeed up to daily allowances and return status 429 once quotas exhaust.
- Cached results under 15 minutes return promptly without invoking upstream Claude or market APIs.
- Cache misses query upstream services, write to `ai_insights`, and log requests in `ai_insight_requests`.
- Invalid ticker symbols fail gracefully without leaving orphaned database records.

## 6. Subscription and entitlement verification
- Test in-app purchases using RevenueCat sandbox environments on iOS and Android, paired with Stripe test modes on web.
- Confirm tier transitions update `profiles.subscription_tier` and unlock or restrict features (such as AI commentary and unlimited trade logs) as subscriptions activate, downgrade, or expire.

## 7. Continuous integration pipeline
The following checks run on pull requests to `main`:
1. `flutter analyze`
2. `flutter test`
3. `supabase test db` (pgTAP database suite)
4. Edge function tests (`deno test` within `supabase/functions/ai-insight/`)

End-to-end integration tests and full manual checklists run prior to milestone releases.

## 8. Out of scope for MVP
- High-volume load and stress testing (deferred until production usage metrics exist).
- Broad visual regression testing across all device form factors beyond core golden files.
- Dedicated penetration testing (scheduled prior to connecting direct brokerage integrations).
