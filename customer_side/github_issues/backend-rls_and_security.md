# [Backend][Authorization and RLS] Verify and close reported role, subscription, application, and version access gaps

## Scope

Customer-side backend audit follow-up for **Authorization and RLS**. Local handoff: `customer_side/backend_issues/rls_and_security.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify signup trigger ignores untrusted role/tier metadata.
- [ ] Protect privileged profile columns and client subscription entitlements from self-upgrade.
- [ ] Verify RLS/grants on affiliate applications and admin authorization for approval RPCs.
- [ ] Authorize public strategy-version reads through visible parent records.
- [ ] Use safe migration design, negative owner/other-user/anonymous tests, and deployment evidence; do not apply audit SQL blindly.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
