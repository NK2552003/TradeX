# [Frontend][Record linking] Refresh ticker search data and measure graph rebuild performance

## Scope

Customer-side frontend audit follow-up for **Record linking**. Local handoff: `customer_side/frontend_issues/features/linking.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Replace stale demo-only ticker universe with current repository/user symbols and explicit loading/error handling.
- [ ] Measure graph rebuilds and note extraction at realistic portfolio sizes; coalesce/debounce expensive work and consider isolates only if measured.
- [ ] Keep graph snapshots internally consistent and avoid losing the last edit when debouncing.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
