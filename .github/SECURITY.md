# AlphaJournal Security Policy

AlphaJournal handles authenticated accounts, private user content, market context, subscriptions, and cross-subdomain sessions. We welcome responsible security research and prioritize reports that help protect users without exposing them publicly.

## Report privately

Use a [GitHub Private Security Advisory](https://github.com/NK2552003/TradeX/security/advisories/new) for any confirmed or suspected exploitable vulnerability, including:

- authentication, session, OTP, recovery, or authorization bypass;
- cross-account or cross-tenant data access;
- subscription, payment, quota, or entitlement bypass;
- exposed secrets, tokens, cookies, signed URLs, private keys, or credentials;
- SQL injection, command injection, XSS, SSRF, insecure deserialization, or path traversal;
- RLS, Storage policy, Edge Function, RPC, webhook, or service-role weaknesses;
- private message, journal, note, strategy, profile, billing, or personal-data disclosure;
- malicious deep-link/app-link interception;
- supply-chain compromise or a dependency vulnerability with a working AlphaJournal impact path.

Do not open a public issue first. A public issue, pull request, discussion, screenshot, recording, or log can make remediation harder and expose users.

## What to include

Provide the smallest safe report that allows us to validate the problem:

1. affected AlphaJournal surface, version, route, function, or endpoint;
2. security impact and the account/role prerequisites;
3. sanitized reproduction steps using test accounts and non-sensitive data;
4. observed result and expected security boundary;
5. OWASP/CWE category if known;
6. suggested remediation or regression test, if available.

Attach sensitive evidence only inside the private advisory. Redact unrelated user data even there. Never send real passwords, full payment data, production private messages, or third-party credentials.

## Public security-hardening issues

The public security issue form is only for non-sensitive hardening work with no active exploit path, no secret exposure, and no private-user evidence. Examples include:

- missing security documentation;
- defense-in-depth improvements;
- a test gap for a security invariant;
- a stale dependency without a demonstrated AlphaJournal exploit;
- a recommended header or platform setting that does not expose users.

If you are uncertain, report privately.

## Supported versions

| Version | Support |
| --- | --- |
| Current production release | Security fixes supported |
| Current release candidate / main branch | Reviewed when relevant to the next release |
| Older releases | Upgrade normally required; critical issues assessed case by case |

## Response targets

These are targets, not guarantees:

| Stage | Target |
| --- | --- |
| Initial acknowledgement | 2 business days |
| Severity and scope triage | 5 business days |
| Remediation plan for confirmed high/critical findings | 10 business days |
| Coordinated disclosure | After a fix is broadly available and users are protected |

Complex, third-party, or multi-platform issues may take longer. We will keep the reporter updated through the private advisory.

## Scope notes

In scope:

- AlphaJournal Flutter applications and web deployment;
- approved `alphajournal.in` subdomains;
- Supabase database, Auth, Storage, Realtime, Edge Functions, and RPC integration;
- billing, webhook, market-data, notification, deep-link, and AI gateway integrations maintained by this repository;
- Android/iOS identifiers under `com.nk2552003.alphajournal`.

Important intended behavior:

- cross-subdomain sessions between approved AlphaJournal origins are required;
- cross-domain support itself is not a vulnerability, but origin bypass, cookie leakage, fixation, or unauthorized session transfer is;
- Unified AI uses a gateway and multiple provider fallbacks by design;
- the GitHub repository name remains `NK2552003/TradeX`; active product branding remains AlphaJournal.

Out of scope:

- denial-of-service testing that can degrade production;
- social engineering, phishing, spam, or physical attacks;
- automated scanning without a validated AlphaJournal-specific impact;
- vulnerabilities solely in a third-party service with no AlphaJournal integration impact;
- attacks requiring a rooted/jailbroken device where no additional AlphaJournal boundary is bypassed.

## Researcher expectations and safe harbor

Act in good faith:

- use your own test accounts and minimum necessary requests;
- stop when you encounter private data that is not yours;
- do not modify, delete, ransom, retain, or publicly disclose data;
- do not degrade availability or access another user's communications;
- give us a reasonable opportunity to remediate before disclosure.

Good-faith research that follows this policy will be treated as authorized for the limited purpose of identifying and reporting vulnerabilities. This policy does not authorize activity against third-party systems or activity prohibited by law.

## After remediation

We will add regression coverage for confirmed issues where practical. Reporter credit is optional and will be given only with the reporter's consent after coordinated disclosure.
