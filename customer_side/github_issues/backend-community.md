# [Backend][Community] Enforce post ownership and block rules; align profile queries

## Scope

Customer-side backend audit follow-up for **Community**. Local handoff: `customer_side/backend_issues/features/community.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify posts/comments read policies implement intended blocked-user visibility semantics.
- [ ] Verify delete/update policies enforce server-side author ownership independently of client filters.
- [ ] Reconcile profile selects and mapping with deployed schema; audit reports username/win_rate/verified column mismatches.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
