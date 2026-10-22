# [Backend][Trade journal] Align strategy joins and private attachment storage

## Scope

Customer-side backend audit follow-up for **Trade journal**. Local handoff: `customer_side/backend_issues/features/journal.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Reconcile strategies(name) joins with actual title/name schema on reads and writes.
- [ ] Align journal attachment upload keys with owner-folder storage policy.
- [ ] Resolve private assets using authorized expiring access rather than unsigned public URLs; cover expiry, deletion, and other-user access.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
