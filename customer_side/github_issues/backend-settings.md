# [Backend][Settings and billing] Fix organization invites, account deletion, and avatar provisioning

## Scope

Customer-side backend audit follow-up for **Settings and billing**. Local handoff: `customer_side/backend_issues/features/settings.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify organization invitations cannot upsert the inviter/owner as the invited member or demote the owner; use token/email-based invites.
- [ ] Implement authorized account-deletion lifecycle, session revocation/sign-out, relational/storage cleanup, and truthful status semantics.
- [ ] Provision/verify avatar storage and owner-write rules; avoid large base64 profile fallbacks on storage errors.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
