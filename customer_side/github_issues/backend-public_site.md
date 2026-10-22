# [Backend][Public site] Surface pricing fallback freshness and synchronize pricing catalogues

## Scope

Customer-side backend audit follow-up for **Public site**. Local handoff: `customer_side/backend_issues/features/public_site.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Make pricing query failures observable and label/cache fallback freshness explicitly.
- [ ] Keep public catalogue, checkout, billing cycle, currency, and subscription entitlements consistent.
- [ ] Test updated pricing, timeout, schema failure, stale cache, and recovery without silent price changes.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
