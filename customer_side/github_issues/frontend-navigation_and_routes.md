# [Frontend][Navigation and deep links] Unify URL routing, platform links, back behavior, and community tab selection

## Scope

Customer-side frontend audit follow-up for **Navigation and deep links**. Local handoff: `customer_side/frontend_issues/navigation_and_routes.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Make auth, shell destinations, feature subtabs, dialogs, and shared entity routes synchronize with browser URL/history.
- [ ] Validate direct links, refresh, browser back/forward, mobile system back, unknown/inaccessible entities, and return after login.
- [ ] Configure supported custom-scheme/app links with required platform/site association files.
- [ ] Clear stale subpage callbacks and avoid destination-history loops; sidebar Feed selection must restore Feed after internal tab changes.
- [ ] Coordinate with closed issue #20 and verify existing deep-link work before replacing architecture.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
