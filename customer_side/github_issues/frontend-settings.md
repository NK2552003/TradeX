# [Frontend][Settings and billing] Complete verification, downloads, support, payment, and deletion feedback

## Scope

Customer-side frontend audit follow-up for **Settings and billing**. Local handoff: `customer_side/frontend_issues/features/settings.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Capture and actually verify email OTPs before showing updated email; connect account linking to real identity operations.
- [ ] Replace discarded card/CVC fields and simulated card saving or plan activation with a configured payment flow, or disable unavailable payment actions.
- [ ] Generate/download real invoice PDFs and ready export archives; handle missing URLs and failures.
- [ ] Persist or deliver support tickets before clearing fields and showing success.
- [ ] Copy referral links to clipboard on both layouts.
- [ ] After accepted deletion/deactivation request, sign out and route through authentication with accurate status copy.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
