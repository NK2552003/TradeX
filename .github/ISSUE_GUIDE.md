# AlphaJournal Issue Guide

Use this guide to route work into the right form and give maintainers enough evidence to act without exposing users.

Related repository guidance:

- [Contributing](../CONTRIBUTING.md)
- [Changelog](../CHANGELOG.md)
- [Security policy](SECURITY.md)
- [Pull request template](PULL_REQUEST_TEMPLATE.md)

## First: is it confidential?

| Situation | Route |
| --- | --- |
| Exploitable vulnerability, authorization bypass, cross-user access, secret/token/cookie exposure, payment bypass, private-data leak | [Private Security Advisory](https://github.com/NK2552003/TradeX/security/advisories/new) |
| Non-sensitive hardening, missing test, or defensive improvement with no exploit details | [Security hardening issue](https://github.com/NK2552003/TradeX/issues/new?template=security.yml) |
| Ordinary product or engineering problem | Choose a public form below |

> [!WARNING]
> Public issues must not contain passwords, OTPs, auth headers, access/refresh tokens, cookies, private keys, service-role keys, database credentials, payment details, private messages, PII, signed URLs, or weaponized exploit steps.

## Choose the best form

| Area | Form |
| --- | --- |
| General reproducible defect | [Bug report](https://github.com/NK2552003/TradeX/issues/new?template=bug.yml) |
| Layout, dock animation, responsive width, accessibility, visual regression | [Frontend / UI / accessibility](https://github.com/NK2552003/TradeX/issues/new?template=frontend_ui.yml) |
| Login, OTP, recovery, sessions, cross-subdomain identity, deep-link callback | [Auth and identity](https://github.com/NK2552003/TradeX/issues/new?template=auth_identity.yml) |
| Supabase RLS, schema, query load, storage/database egress, caching | [Database and egress](https://github.com/NK2552003/TradeX/issues/new?template=database_egress.yml) |
| Plans, RevenueCat, Razorpay, quotas, Free/Basic/Pro access | [Billing and entitlements](https://github.com/NK2552003/TradeX/issues/new?template=billing_entitlements.yml) |
| World Indices, Assets, quotes, news, screeners, synchronization | [Market data](https://github.com/NK2552003/TradeX/issues/new?template=market_data.yml) |
| Unified AI, gateway, providers, streaming, copilot, research | [AI and copilot](https://github.com/NK2552003/TradeX/issues/new?template=ai_copilot.yml) |
| Community posts, private Messages, moderation, privacy | [Community and messages](https://github.com/NK2552003/TradeX/issues/new?template=community_messages.yml) |
| Android/iOS/PWA installation, App Links, Universal Links, notifications | [Mobile, PWA, and links](https://github.com/NK2552003/TradeX/issues/new?template=mobile_links.yml) |
| Slow startup, jank, excess calls, memory, bundle size | [Performance](https://github.com/NK2552003/TradeX/issues/new?template=performance.yml) |
| CI, deployment, migration, store release, production readiness | [Deployment and release](https://github.com/NK2552003/TradeX/issues/new?template=deployment_release.yml) |
| New capability or product improvement | [Feature request](https://github.com/NK2552003/TradeX/issues/new?template=feature_request.yml) |
| Incorrect, missing, or outdated docs | [Documentation](https://github.com/NK2552003/TradeX/issues/new?template=documentation.yml) |

## Evidence checklist

Strong public reports include:

- affected AlphaJournal version/commit and environment;
- platform, browser/device, screen size, and account tier;
- smallest sanitized reproduction;
- expected versus actual behavior;
- impact and frequency;
- redacted screenshots, recordings, traces, or logs;
- the last known-good version, if known;
- acceptance criteria and a regression-test idea.

Use test data. Crop or redact account names, email addresses, IDs, messages, invoice details, API responses, and URLs containing signatures or tokens.

## Severity guide

| Severity | Meaning | Handling |
| --- | --- | --- |
| Critical | Active compromise, secret exposure, auth/tenant/payment bypass, broad private-data loss | Private advisory; stop release |
| High | Major security/privacy/data-loss risk or a core flow unusable without workaround | Private advisory if security-sensitive; release blocker |
| Medium | Important malfunction with a workaround or limited scope | Prioritized issue |
| Low | Cosmetic, copy, minor usability, or low-impact hardening | Normal backlog |

## AlphaJournal invariants

Reports and fixes must preserve:

- repository name `NK2552003/TradeX`, while product branding remains AlphaJournal;
- cross-subdomain sessions for approved `*.alphajournal.in` origins;
- Unified AI gateway and multi-provider fallback behavior;
- Free users limited to Community market previews;
- Basic/Pro gating for full Market Intelligence, Messages, and advanced calculators;
- consolidated World Indices and Assets tables and their CI synchronization;
- server-side/RLS enforcement in addition to UI gates.

## Before submitting

- [ ] I selected the narrowest matching form.
- [ ] I removed secrets and unrelated user data.
- [ ] I searched existing open and closed issues.
- [ ] I separated unrelated defects into separate reports.
- [ ] I included a testable outcome.
