# [Frontend][Workspace] Validate carousel controls and retain search and filter state

## Scope

Customer-side frontend audit follow-up for **Workspace**. Local handoff: `customer_side/frontend_issues/features/workspace.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Reproduce Writing Desk carousel arrow overlap at 768–904 px; keep navigation controls outside card hit areas.
- [ ] Retain search queries, date filters, and relevant scroll state after opening and closing note/trade/strategy editors.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
