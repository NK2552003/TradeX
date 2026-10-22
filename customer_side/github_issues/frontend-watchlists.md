# [Frontend][Watchlists] Implement symbol picker and ticker navigation; distinguish prices from alert targets

## Scope

Customer-side frontend audit follow-up for **Watchlists**. Local handoff: `customer_side/frontend_issues/features/watchlists.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Replace Add Symbol toast with a searchable symbol/watchlist picker and working persistence.
- [ ] Open the selected instrument/chart from ticker rows instead of storing unread selection state.
- [ ] Never render alert thresholds or a fabricated fallback as current prices; use available quotes with provenance and explicit unavailable states.
- [ ] Cover empty, loading, failed save, duplicate symbols, and successful add/remove flows.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
