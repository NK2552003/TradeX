# [Backend][Record linking] Correct UUID generation and require authenticated link ownership

## Scope

Customer-side backend audit follow-up for **Record linking**. Local handoff: `customer_side/backend_issues/features/linking.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify etl_* synthetic identifiers against UUID columns and replace invalid payloads.
- [ ] Require a valid authenticated owner; never sync demo_user as a profile foreign key.
- [ ] Test link/unlink, duplicates, other-user records, and restored graph consistency.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
