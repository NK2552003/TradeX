# [Frontend][Direct messages] Correct security copy, composer insets, and authenticated empty states

## Scope

Customer-side frontend audit follow-up for **Direct messages**. Local handoff: `customer_side/frontend_issues/features/messages.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Remove unsupported end-to-end encryption claims and associated misleading lock affordances.
- [ ] Verify composer safe areas and keyboard layout on gesture-navigation devices; retain already-correct SafeArea behavior.
- [ ] Clear demo personas when authenticated fetch returns an empty thread list; preserve explicit error and empty states.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
