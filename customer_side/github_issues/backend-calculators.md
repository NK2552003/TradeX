# [Backend][Calculators] Persist calculator history and version statutory tax assumptions

## Scope

Customer-side backend audit follow-up for **Calculators**. Local handoff: `customer_side/backend_issues/features/calculators.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Connect calculator history persistence to the actual schema and enable appropriate owner-scoped access.
- [ ] Store calculator version, input/output assumptions, and timestamps so historical calculations remain interpretable.
- [ ] Validate statutory capital-gains rates/exemptions and effective dates against authoritative sources before updating formulas.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
