# [Frontend][Affiliate program] Replace false phone verification, complete referral copying, and clarify payouts

## Scope

Customer-side frontend audit follow-up for **Affiliate program**. Local handoff: `customer_side/frontend_issues/features/affiliate_program.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Replace instant phone-verified flag with actual OTP send/verify states or mark verification unavailable.
- [ ] Ensure mobile and desktop Copy Link actually use the clipboard and report errors.
- [ ] Connect payout requests to supported backend operations or make availability explicit; do not imply a transfer occurred from a simulated modal.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
