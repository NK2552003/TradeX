# [Backend][AI assistant] Use valid note identifiers and authenticated streaming model service

## Scope

Customer-side backend audit follow-up for **AI assistant**. Local handoff: `customer_side/backend_issues/features/ai_assistant.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify generated note_ai_* IDs against UUID columns; generate valid IDs or let the database assign them.
- [ ] Implement authenticated streaming model service with server-side provider credentials, authorization for portfolio context, limits, cancellation, and error handling.
- [ ] Do not prescribe obsolete provider/model versions from the audit; select and document supported configuration.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
