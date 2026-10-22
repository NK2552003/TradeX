# [Backend][Workspace] Batch linked post reads and enforce valid relational identifiers

## Scope

Customer-side backend audit follow-up for **Workspace**. Local handoff: `customer_side/backend_issues/features/workspace.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Replace sequential per-edge post queries with batched authorized lookup while preserving ordering and missing-record behavior.
- [ ] Do not insert synthetic post-* IDs into UUID relational fields; use real persisted post identifiers.
- [ ] Test empty links, deleted posts, partial visibility, and realistic portfolio performance.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
