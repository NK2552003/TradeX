# [Frontend][Strategies] Protect publishing and owner links; validate editor menus and tablet split mode

## Scope

Customer-side frontend audit follow-up for **Strategies**. Local handoff: `customer_side/frontend_issues/features/strategies.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Validate the header More menu actually opens and actions work with the shared dropdown component.
- [ ] Use write/read mode when local width cannot support split panes; test portrait tablets and resize after selecting Split.
- [ ] Preserve owners private linked records in their own workspace.
- [ ] Require an explicit visibility warning and confirmation before publishing a strategy.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
