# [Frontend][Trade journal] Fix compact trade views, owner link visibility, and calculator handoff

## Scope

Customer-side frontend audit follow-up for **Trade journal**. Local handoff: `customer_side/frontend_issues/features/journal.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Use readable trade cards on compact widths and horizontally scrollable tables when needed on larger widths.
- [ ] Decouple public-record visibility from viewer permissions: owners in private workspace must retain access to their private linked records.
- [ ] Accept initial trade drafts from calculator outputs without silently changing values; provide a Log Trade action from calculators.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
