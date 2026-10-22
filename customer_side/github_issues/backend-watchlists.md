# [Backend][Watchlists] Reconcile item schema and integrate quote data

## Scope

Customer-side backend audit follow-up for **Watchlists**. Local handoff: `customer_side/backend_issues/features/watchlists.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify deployed watchlist_items schema before choosing a migration or client change: audit reports symbol versus ticker plus missing category/favorite/alert fields.
- [ ] Join symbols to quotes with explicit freshness/unavailable values; alert targets must remain separate from prices.
- [ ] Require authenticated ownership and test list/item create/read/update/delete.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
