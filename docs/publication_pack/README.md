# alphajournal India publication pack

This folder contains **15 editable Word documents** for an India-first alphajournal launch. The documents are drafts for business, product, tax, and legal approval. They are not evidence that planned payment rails or advertised features are live. `generate_documents.py` is the editable source and uses the third-party `python-docx` library.

## Contents

1. Privacy Policy
2. Terms of Service
3. Cookie and Similar Technologies Policy
4. Cookie Consent Notice and Deployment Specification
5. Subscription Cancellation and Refund Policy
6. Trading and AI Risk Disclaimer
7. End User License Agreement
8. Acceptable Use Policy
9. Community Guidelines and Content Policy
10. Affiliate Program Agreement
11. Affiliate Marketing and Brand Guidelines
12. Affiliate Commission Payout and Tax Policy
13. Account Deletion and Data Retention Policy
14. Security and Incident Communication Policy
15. Product Operations and Publication Guide

## Before publishing

Replace every bracketed field in **all** Word documents: legal entity, Indian registered address, support/privacy/security email, external deletion URL, effective date, consent and web owners, affiliate terms version, affiliate dispute period, liability cap, Indian court city, and deployment date. Confirm age eligibility, data retention periods, real data processors, refund service time, and store-specific billing terms.

Resolve these product and legal mismatches before accepting payments or publishing promises:

- The SQL and app copy call **5% TDS** statutory under Section 194H. The Income Tax Department's current text states **2%** under that section, subject to threshold and applicability. Obtain tax advice and align the calculation, UI, seeded terms, certificates, and documents.
- `implementation.md` describes affiliate tiers of **15% and 30%**; migration `027_admin_affiliate_inr_deletion_production.sql` seeds **15%, 20%, 25%, and 35%**. Choose one approved schedule and use it throughout the product and legal acceptance flow.
- The public pricing catalogue includes Enterprise, live market feed, broker, AI, and SLA claims that the root implementation plan excludes from launch scope. Confirm each production capability and remove unsupported claims.
- The current `SubscriptionPricingRepositoryImpl.selectPlan()` selects a local session plan; it explicitly says paid checkout must be confirmed server-side. Verify real purchase, webhook, invoice, entitlement, renewal, cancellation, and refund paths before describing them as live.
- The footer currently asserts SOC 2, uptime, latency, and broker integrations. Publish only independently verified claims.
- The cookie policy has a starter inventory. Audit deployed browser storage and all analytics/ad scripts before showing a consent banner or naming vendors.

## Publication map

- **Public footer and account settings:** Privacy, Terms, Cookies, Refund, Risk, EULA, Acceptable Use, Community, and Deletion.
- **Consent interface:** Cookie Consent Notice and Deployment Specification, linked to the Cookie Policy.
- **Affiliate application and versioned acceptance:** Affiliate Agreement, Marketing Guidelines, and Commission Payout and Tax Policy.
- **App stores:** Public privacy URL and in-app deletion route; Google Play also requires an external deletion request URL when users can create accounts in-app.
- **Internal release record:** Product Operations and Publication Guide, approved versions, date, test evidence, and legal/tax sign-off.

## Source basis

Repository: `implementation.md`, `assets/data/pricing_catalogue.json`, `lib/features/auth/data/repositories/subscription_pricing_repository.dart`, affiliate pages and attribution code, migrations `026` and `027`, account deletion UI and SQL, and footer legal/status copy. The plan is a blueprint, so code and deployed behavior should determine final operational claims.

Official India and platform references reviewed on 26 October 2026:

- [DPDP Rules and commencement notices](https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa?pageTitle=Digital-Personal-Data-Protection-Rules-2025%3B)
- [Income Tax Act Section 194H](https://www.incometaxindia.gov.in/w/section-194h-34)
- [Consumer Protection E-Commerce Rules](https://consumeraffairs.nic.in/acts-and-rules/consumer-protection/consumer-protection)
- [ASCI influencer advertising guidelines](https://www.ascionline.in/the-asci-code-guidelines/)
- [SEBI regulatory materials](https://www.sebi.gov.in/sebiweb/home/HomeAction.do?doListing=yes&sid=1&smid=0%2F&ssid=3)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)

## Rebuild

Use the bundled Codex Python runtime with `python-docx` to run `generate_documents.py`; then render and inspect every DOCX page before distribution. The generator overwrites the 15 numbered Word files, so update its source rather than editing generated files alone.

Technical setup and release status: [Billing and publication handoff](../ALPHAJOURNAL_BILLING_AND_PUBLICATION.md).
