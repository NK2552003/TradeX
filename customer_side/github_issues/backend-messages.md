# [Backend][Direct messages] Validate participant authorization for realtime delivery and message storage

## Scope

Customer-side backend audit follow-up for **Direct messages**. Local handoff: `customer_side/backend_issues/features/messages.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify deployed Realtime/table policies prevent message access outside authorized participants; a global channel name alone does not prove leakage.
- [ ] Scope delivery/subscriptions to authorized threads and test users A/B/C plus unauthenticated clients.
- [ ] Align message storage and security claims; if E2EE is required, design key management and ciphertext storage explicitly.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
