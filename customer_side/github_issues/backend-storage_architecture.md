# [Backend][Attachment storage] Align object paths, signed access, avatar provisioning, and storage policies

## Scope

Customer-side backend audit follow-up for **Attachment storage**. Local handoff: `customer_side/backend_issues/storage_architecture.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Verify note/journal/strategy/community object keys match owner-folder policies, generally user/entity/file.
- [ ] Use authorized signed access for private buckets, with expiry and cache invalidation.
- [ ] Verify avatar/community bucket provisioning, MIME/size limits, intended read access, and owner writes.
- [ ] Test upload, read, replacement, deletion, public sharing, and cross-user denial without exposing private attachments.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Verify deployed schema, policies, and service configuration before choosing migrations.
- [ ] Test owner, another user, and unauthenticated access where relevant; document deployment dependencies.
- [ ] Add focused regressions and report remaining validation limits.
