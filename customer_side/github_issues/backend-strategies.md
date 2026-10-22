# [Backend][Strategies] Authorize public versions and fix attachment paths and link update races

## Scope

Customer-side backend audit follow-up for **Strategies**. Local handoff: `customer_side/backend_issues/features/strategies.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify public strategy versions are readable only when their parent is publicly visible, with owner access retained.
- [ ] Correct strategy attachment keys and signed URL resolution.
- [ ] Resolve manual linked-note-array writes racing with link graph triggers; choose one authoritative mutation path and test concurrent edits.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
