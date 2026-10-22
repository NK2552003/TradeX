# [Frontend][Authentication and onboarding] Wire OAuth and recovery completion; validate compact auth layouts

## Scope

Customer-side frontend audit follow-up for **Authentication and onboarding**. Local handoff: `customer_side/frontend_issues/features/auth.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Connect Google sign-in/sign-up controls to the real OAuth flow; show failures and configuration gaps.
- [ ] Replace the password reset completion timer with a verified recovery-session password update; handle send, verify, resend, update failures and duplicate submits.
- [ ] Restrict production role switching to authorized roles; validate that UI switching cannot grant admin privileges.
- [ ] Reproduce onboarding landscape/scaled-text overflow and auth keyboard occlusion; keep fields and actions scrollable.
- [ ] Remove unsupported client-side encryption claims.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
