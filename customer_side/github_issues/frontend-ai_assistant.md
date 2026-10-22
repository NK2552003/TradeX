# [Frontend][AI assistant] Validate action menus and replace simulated response streaming

## Scope

Customer-side frontend audit follow-up for **AI assistant**. Local handoff: `customer_side/frontend_issues/features/ai_assistant.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Validate chat header and insight dropdown triggers, keyboard activation, and action results.
- [ ] Replace artificial typing of canned responses with authenticated service streaming when configured.
- [ ] Handle cancellation, timeout, failure, unavailable service, and response completion honestly; avoid claiming model output for local demo responses.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
