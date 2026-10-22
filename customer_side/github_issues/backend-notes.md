# [Backend][Notes] Fix private attachment uploads and integrate authenticated AI refactoring

## Scope

Customer-side backend audit follow-up for **Notes**. Local handoff: `customer_side/backend_issues/features/notes.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Align note upload keys with owner-scoped storage policy and correct attachment metadata.
- [ ] Use authorized expiring URLs for private note attachments and handle expiry/cache invalidation.
- [ ] Integrate the planned authenticated note refactoring service instead of silently returning local regex output as AI.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
