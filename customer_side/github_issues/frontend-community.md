# [Frontend][Community] Complete post actions and refresh; protect attachment visibility and compact navigation

## Scope

Customer-side frontend audit follow-up for **Community**. Local handoff: `customer_side/frontend_issues/features/community.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Implement Quote, Mute, and Report actions or clearly disable unavailable actions.
- [ ] Make pull-to-refresh await repository reload, including errors.
- [ ] Verify embedded community navigation has one bottom dock and usable top-level/subtab selection.
- [ ] Ensure compact action touch targets remain accessible.
- [ ] Require explicit confirmation before making attached private notes, strategies, or trades public; cancel must preserve visibility.
- [ ] Remove the fabricated advisor registration number; render only verified profile information.
- [ ] Label simulated audio rooms as unavailable/beta unless actual transport is connected.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
