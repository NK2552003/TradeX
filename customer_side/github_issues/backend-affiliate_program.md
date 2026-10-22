# [Backend][Affiliate program] Protect application data and approvals; credit only verified conversions

## Scope

Customer-side backend audit follow-up for **Affiliate program**. Local handoff: `customer_side/backend_issues/features/affiliate_program.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify RLS and grants protect applicant banking/tax/contact records from unauthenticated and other-user access.
- [ ] Require authorized administrators for application approval RPCs; constrain commission updates.
- [ ] Remove signup-only balance credits; credit only verified eligible conversions/payment events with idempotency and reversal behavior.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
