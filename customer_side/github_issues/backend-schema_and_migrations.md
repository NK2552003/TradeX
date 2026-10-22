# [Backend][Schema compatibility] Reconcile repository queries, UUID payloads, and migration contracts

## Scope

Customer-side backend audit follow-up for **Schema compatibility**. Local handoff: `customer_side/backend_issues/schema_and_migrations.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify strategies title/name joins and watchlist symbol/ticker plus optional columns against deployed schema.
- [ ] Correct invalid prefixed IDs and demo foreign keys across linking, AI-created notes, and workspace edges.
- [ ] Connect calculator_history with owner policies and documented payloads.
- [ ] Use non-destructive migrations, regenerate/verify contracts, and test real CRUD; coordinate feature fixes with closed backend issues #16 and #17.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
