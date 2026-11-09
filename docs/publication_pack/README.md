# Alphajournal publication pack

This pack contains **23 complete documents**, readable Markdown editions and the bundled in-app library. Policies use the service name **Alphajournal**, the contact **h82292245@gmail.com**, and the effective date **9 November 2026**. No draft labels or unresolved bracketed fields appear in the current documents.

The `/settings_help` page provides search, topic selection and full-width title-and-arrow navigation. Public `/help` and `/help/:document` routes make the same documents available without signing in. Document details contain the full text, an update date, expandable sections and support information.

## Document index

| Document | Reader route | Source |
| --- | --- | --- |
| Privacy Policy | `/help/privacy` | [Read](readable/privacy.md) |
| Terms of Service | `/help/terms` | [Read](readable/terms.md) |
| Cookie and Similar Technologies Policy | `/help/cookies` | [Read](readable/cookies.md) |
| Cookie Consent Notice and Deployment Specification | `/help/consent-specification` | [Read](readable/consent-specification.md) |
| Subscription Cancellation and Refund Policy | `/help/refunds` | [Read](readable/refunds.md) |
| Trading and AI Risk Disclaimer | `/help/trading-risk` | [Read](readable/trading-risk.md) |
| End User License Agreement | `/help/eula` | [Read](readable/eula.md) |
| Acceptable Use Policy | `/help/acceptable-use` | [Read](readable/acceptable-use.md) |
| Community Guidelines and Content Policy | `/help/community` | [Read](readable/community.md) |
| Affiliate Program Agreement | `/help/affiliate-agreement` | [Read](readable/affiliate-agreement.md) |
| Affiliate Marketing and Brand Guidelines | `/help/affiliate-marketing` | [Read](readable/affiliate-marketing.md) |
| Affiliate Commission Payout and Tax Policy | `/help/affiliate-payouts` | [Read](readable/affiliate-payouts.md) |
| Account Deletion and Data Retention Policy | `/help/account-deletion` | [Read](readable/account-deletion.md) |
| Security and Incident Communication Policy | `/help/security` | [Read](readable/security.md) |
| Product Operations and Publication Guide | `/help/publication-guide` | [Read](readable/publication-guide.md) |
| Advertising and Sponsored Content Policy | `/help/advertising` | [Read](readable/advertising.md) |
| Browser App Installation and Device Guide | `/help/install` | [Read](readable/install.md) |
| Workspace User Guide and FAQ | `/help/user-guide` | [Read](readable/user-guide.md) |
| Support Complaints and Privacy Requests | `/help/support` | [Read](readable/support.md) |
| Accessibility and Device Permissions Guide | `/help/accessibility` | [Read](readable/accessibility.md) |
| Storage Vendor and Retention Register | `/help/storage-register` | [Read](readable/storage-register.md) |
| Consent Advertising and Installation Implementation Guide | `/help/implementation` | [Read](readable/implementation.md) |
| Help Centre Release Notes | `/help/release-notes` | [Read](readable/release-notes.md) |

Each numbered Word file has the corresponding document title. The older October ZIP is historical; use the November package for this revision.

## Cookie behaviour

- Necessary storage remains available for sign-in and requested features.
- Optional analytics, advertising, personalised ads and automatic affiliate attribution default off.
- Accept optional, Reject optional and granular Save choices persist a versioned preference on this device for 180 days.
- Personalised ads cannot remain enabled when advertising is disabled.
- Invalid, expired, future-dated and obsolete records fail closed. Closing the notice is not consent.
- Withdrawal removes local affiliate attribution and visitor identifiers. Account session records remain intact.
- Storage failures show an error; optional activity remains off and the user can continue with essential storage.
- Browser focus and storage changes refresh choices so another tab's saved decision is observed. Other devices have independent choices.
- Privacy settings, help and public footer links reopen the same controls.

These are local privacy preferences, not contract acceptance records or a certified CMP. No analytics or AdSense SDK is activated by this work.

## Advertising rollout

Google AdSense is the chosen future provider for free-version ads. Adding a publisher ID alone is insufficient: configure the approved site, the applicable Google-certified CMP, eligible routes and plans, provider disclosures and any required ads.txt. Never initialise tags before the relevant permissions are known. Exclude private journals, messages, research, account, billing, deletion and security screens. Verify actual requests for sensitive content, URLs and referrers.

Do not promise an ad-free paid tier unless checkout and entitlements enforce it. Non-personalised advertising can still require consent. Test using provider-supported methods, never by clicking live ads.

Google source: [Publisher consent requirements](https://support.google.com/adsense/answer/13554116), [Partner-site data use](https://policies.google.com/technologies/partner-sites), [Advertising technologies](https://policies.google.com/technologies/ads). Reviewed 9 November 2026; recheck when enabling the service.

## Browser installation

`web/app_install.js` captures a real browser install event before Flutter starts. The user-triggered action consumes the event once; acceptance is distinguished from confirmed installation. Suggestions respect standalone state and a seven-day dismissal cooldown. Browsers without this event receive instructions. Installation does not grant cookies, device permissions, a subscription or offline capability.

Reference: [MDN beforeinstallprompt](https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeinstallprompt_event).

## Authoring and rebuild

`publication_policies.py` contains the public policies. `publication_expansion.py` contains additional guides and advertising material. `generate_documents.py` produces all numbered DOCX files, `readable/*.md`, and `assets/legal/publication_library.json` from these sources. Edit the sources and rebuild all formats together.

```sh
python3 docs/publication_pack/generate_documents.py
```

Requires `python-docx`. Render and inspect the Word files after any layout or content changes. The generator must not contain credentials or undocumented security claims. Keep retention statements tied to actual operating criteria; update notices when providers or processing purposes change. Obtain appropriate review for jurisdiction-specific or material legal changes. The policies do not assert independent legal certification.

## Verification scripts

```sh
flutter test test/core/privacy/consent_preferences_test.dart test/features/settings/help_centre_test.dart
node --test test/web/app_install_test.cjs
python3 docs/publication_pack/verify_publication_pack.py
flutter build web --release
```

The tests cover consent expiry, corrupted records, persistence, storage errors, withdrawal, attribution gating, the actual accept/reject/custom UI buttons, full-text search, readable document navigation, large-text layouts and install event lifecycle. Real-device browser eligibility and a configured AdSense/CMP require deployment-specific verification.

Technical and commercial reference: [Billing and publication handoff](../ALPHAJOURNAL_BILLING_AND_PUBLICATION.md).
