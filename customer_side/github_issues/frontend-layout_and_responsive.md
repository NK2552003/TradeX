# [Frontend][Responsive layouts and shared components] Audit compact layouts, keyboard ownership, touch targets, and resize behavior

## Scope

Customer-side frontend audit follow-up for **Responsive layouts and shared components**. Local handoff: `customer_side/frontend_issues/layout_and_responsive.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify onboarding landscape/large-text scrolling, journal table readability, editor split thresholds, and pricing labels.
- [ ] Assign keyboard inset ownership once across notes/journal/strategy toolbars and slash palettes.
- [ ] Verify one embedded community bottom dock, message composer safe area, accessible action targets, and chart edge-back gestures.
- [ ] Validate Writing Desk carousel arrow positions at intermediate widths; fix shared components where the defect originates.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
