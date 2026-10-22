# [Backend][Authentication and onboarding] Harden signup authorization, OTP failures, and session persistence

## Scope

Customer-side backend audit follow-up for **Authentication and onboarding**. Local handoff: `customer_side/backend_issues/features/auth.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify signup trigger role/tier defaults; never trust self-signup user metadata for admin authorization or enterprise entitlements.
- [ ] Remove production mock OTP fallback on network/verification failures; fail closed without accepting arbitrary codes.
- [ ] Review access/refresh token persistence and use supported secure platform storage; distinguish browser constraints.
- [ ] Check deployed policies/configuration and add negative auth regression tests.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
