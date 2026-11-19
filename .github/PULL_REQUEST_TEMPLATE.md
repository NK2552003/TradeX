## Outcome

<!-- Lead with the user-visible or operational result. -->

## Related work

<!-- Link public issues. Reference private advisories only where access and disclosure timing are appropriate. -->

Closes #

## What changed

- 

## Evidence

### Validation

<!-- List exact commands and results. -->

- [ ] `dart analyze`
- [ ] Relevant Flutter tests
- [ ] Relevant Node/database/Edge Function tests
- [ ] `git diff --check`

### UI evidence

<!-- Add redacted screenshots/recordings for UI work at relevant mobile and desktop widths. -->

## Risk review

- [ ] No secret, credential, token, cookie, OTP, private key, signed URL, payment data, private message, or PII is included.
- [ ] Active product branding is AlphaJournal; only the repository name remains TradeX.
- [ ] Existing shared app-ui/flutter-ui components are used where available.
- [ ] Mobile, desktop, accessibility, text scaling, focus, loading, error, empty, and retry states were considered.
- [ ] Cross-subdomain session/CORS behavior is preserved or intentionally tested.
- [ ] Unified AI gateway/provider fallback behavior is preserved or the architecture change is explicitly approved.

## Entitlements and data

- [ ] Not applicable.
- [ ] Free/Basic/Pro behavior is documented and tested.
- [ ] Ineligible users do not start paid network, realtime, database, or AI calls.
- [ ] Backend/RPC/RLS enforcement matches client gating.
- [ ] Query volume, caching, pagination, storage/database egress, and cleanup were reviewed.

## Database and deployment

- [ ] Not applicable.
- [ ] A forward-only migration was added; applied migrations were not edited.
- [ ] RLS, ownership, `USING`/`WITH CHECK`, grants, views, and privileged functions were reviewed.
- [ ] Staging verification and advisor output are attached or linked.
- [ ] Rollout, compatibility, and rollback steps are documented.

## Documentation and release notes

- [ ] Documentation is unchanged because behavior/configuration did not change.
- [ ] Relevant documentation was updated.
- [ ] `CHANGELOG.md` was updated under **Unreleased**.

## Reviewer focus

<!-- Point reviewers to the highest-risk decisions and files. -->
