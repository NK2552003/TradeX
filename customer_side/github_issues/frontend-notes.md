# [Frontend][Notes] Correct keyboard overlays, link privacy, HTML actions, and attachment export boundaries

## Scope

Customer-side frontend audit follow-up for **Notes**. Local handoff: `customer_side/frontend_issues/features/notes.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Prevent arbitrary local file reads during Markdown/PDF image resolution; enforce canonical app attachment boundaries, including traversal and symlinks.
- [ ] Correct toolbar and slash palette keyboard inset ownership; test small heights and keyboard open/closed.
- [ ] Measure large-note parsing and debounce expensive extraction without stale saved content.
- [ ] Make safe HTML anchors actionable with approved URL schemes.
- [ ] Preserve owners access to private linked records while filtering public viewers.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
