# Storage Vendor and Retention Register

Release resource | Updated 2026-11-09

A repository-based inventory and deployment worksheet for verifying the public notices. This is a release resource, not a completed production processor register.

## Consent preference

SharedPreferences key alphajournal_consent_v1; owner Alphajournal; purpose remember optional choices; fields schema version, UTC saved time, analytics, advertising, personalised ads and affiliate choice; validity 180 days; renewed on a saved choice; rejection does not delete the necessary preference record. Browser key names may be prefixed flutter. Verify the built app storage backend.

## Install suggestion

Web local-storage key alphajournal_install_dismissed_v1; owner Alphajournal; value last dismissal time; purpose avoid repeated installation prompts; suppression seven days; physical timestamp retained until overwritten or cleared. No third-party request is made by app_install.js.

## Affiliate attribution

SharedPreferences affiliate_attribution_v1 and affiliate_visitor_v1; purpose optional automatic referral attribution and campaign click measurement; valid referral window less than 30 days; removal on rejection or withdrawal, invalid or expired attribution, and completed conversion. Manual signup codes remain a separate user-requested input. Verify server click records and their retention separately.

## Authentication and workspace preferences

Source auth_session_storage.dart uses auth_session_user_id, auth_session_email, auth_session_role, auth_session_profile, auth_session_affiliate_profile, auth_session_token, auth_session_timestamp, auth_has_seen_onboarding, app_scaffold_last_destination and auth_workspace_role_<userId>. The authentication SDK may use additional session storage. These are account/session or requested preference records, not advertising categories. Do not publish an invented uniform expiry: test logout, refresh, account switching, deletion and SDK behaviour.

## Workspace caches and content

The repository includes local workspace preferences and caches such as alphajournal_affiliate_workspace_v2_inr, note drafts and other feature-specific records. Enumerate actual local storage, IndexedDB, cookies and Cache Storage on clean production profiles. This list is a starting inventory, not an exhaustive deployment audit. Record each name, owner, purpose, data fields, storage mechanism, retention and removal trigger.

## Google AdSense

Planned; no tag currently enabled. Before rollout enter publisher ID, account owner, supported sites, processors, allowed locations, ad formats, active cookie names and durations observed in a production-like audit, CMP identity and version, regional rules, opt-out links and removal limits. Do not list example Google cookie names as observed facts.

## Other providers

The source includes Supabase-backed account/data services, payment integrations, Google Fonts and optional AI/external links. Configuration and actual traffic determine which vendors are live. Verify hosting, auth, email, billing, analytics, AI, content delivery and error reporting independently. Record legal vendor name, role, purpose, data, location, contract, retention and contact. Never copy credentials or secret environment values into this register.

## Retention approval worksheet

For account profiles, private content, public posts, messages, attachments, support tickets, security logs, consent evidence, referral clicks, invoices, affiliate tax records and backups, assign an owner and approve a duration or clear deletion criterion. Record legal basis, active-system purge, backup expiration, vendor deletion and verification. Unconfirmed periods remain release blockers, not promises to users.

## Audit procedure

Start with a clean browser and record storage and requests before interaction. Repeat reject, granular accept, all accept, withdrawal, refresh, expiry, sign-in, sign-out and installation. Inspect URLs and payloads for private data. Compare authenticated and public routes and paid/free eligibility. Capture browser version, build hash, time, observer and findings without retaining credentials.
