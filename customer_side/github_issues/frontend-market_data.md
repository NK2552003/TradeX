# [Frontend][Market intelligence] Validate chart edge gestures, mover targets, and snapshot disclosures

## Scope

Customer-side frontend audit follow-up for **Market intelligence**. Local handoff: `customer_side/frontend_issues/features/market_data.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Reproduce chart horizontal pan versus operating-system edge-back behavior; preserve back gestures.
- [ ] Validate mover ticker pills at 320/360 px and accessible touch targets without clipped change badges.
- [ ] Display accurate snapshot timestamps/staleness and analytics/non-advisory context; do not claim an invented 15-minute delay.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
