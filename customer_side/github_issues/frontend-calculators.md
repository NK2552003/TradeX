# [Frontend][Calculators] Guard invalid arithmetic, review tax regimes, and connect journal drafts

## Scope

Customer-side frontend audit follow-up for **Calculators**. Local handoff: `customer_side/frontend_issues/features/calculators.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Guard zero risk, invalid numeric input, NaN, and Infinity before rendering ratios/progress.
- [ ] Verify statutory capital gains assumptions against authoritative sources and transaction dates; support labeled historical regimes where required. Audit reports old STCG/LTCG rates and exemptions.
- [ ] Transfer position-size and risk/reward outputs into a journal draft with explicit user review.
- [ ] Validate all calculator layouts and compact clear-button targets.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
