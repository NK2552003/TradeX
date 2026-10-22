# [Frontend][Public site] Fix narrow pricing typography and footer links; remove unsupported security claims

## Scope

Customer-side frontend audit follow-up for **Public site**. Local handoff: `customer_side/frontend_issues/features/public_site.md`.

## Triage status

These are reported audit findings, not confirmation of deployed behavior. Reproduce each against the current checkout and configured environment; record stale findings as already resolved. Absolute failure rates and production exposure claims in the source audit remain unverified.

## Work items

- [ ] Validate localized annual/monthly price labels at 320/360 px and large text; prevent wrapping/clipping.
- [ ] Make footer social controls open verified project destinations, or remove/disable unconfigured destinations.
- [ ] Remove unsupported AES-256/client-encryption and other security claims throughout public copy.

## Validation and completion

- [ ] Record reproductions, affected code paths, and evidence for each confirmed defect.
- [ ] Preserve unrelated work and coordinate shared fixes with related feature issues.
- [ ] Use TraderHub shared components and context design tokens required by AGENTS.md.
- [ ] Validate affected flows at 320, 390, 768, 1024, and 1440 px, including keyboard, touch, scaling, resize, and back navigation as applicable.
- [ ] Cover loading, empty, error, success, and unavailable-service states without simulated success.
- [ ] Add focused regressions and report remaining validation limits.
