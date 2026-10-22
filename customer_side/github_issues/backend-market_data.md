# [Backend][Market intelligence] Replace frozen quote delivery and direct browser quote scraping

## Scope

Customer-side backend audit follow-up for **Market intelligence**. Local handoff: `customer_side/backend_issues/features/market_data.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Define licensed/current quote delivery, timestamps, freshness, limits, caching, and failure behavior rather than presenting bundled snapshots as live.
- [ ] Proxy browser quote requests through a supported backend; audit reports direct Yahoo requests failing CORS/rate limits.
- [ ] Keep provider credentials server-side and validate authorized access and request limits.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
