# Consent Advertising and Installation Implementation Guide

Release resource | Updated 2026-11-09

Engineering and operational requirements for the implemented choices and installation experience, and the remaining Google AdSense launch work.

## Architecture

ConsentController owns local versioned choices through SharedPreferences. Optional categories fail closed when records are missing, corrupt, expired or from a different schema. CookiePreferencesDialog is shared by the first web visit and help centre. BrowserExperienceGate sequences the cookie notice before any eligible install suggestion. Native builds provide help without a browser installation prompt.

## Future ad integration contract

No advertising SDK is loaded by this release. Before adding one, create an adapter that waits for known local consent, required CMP approval, verified free-plan eligibility and a reviewed public-content route. Recheck permission before every request and stop listeners or tear down optional SDKs on withdrawal. Do not initialise vendor tags in index.html, preconnect to ad endpoints before choice or send cookieless pings on an assumed exemption. Keep optional requests off when eligibility or consent is unknown.

## Google regional requirements

Google requires a certified CMP integrated with its required TCF framework for covered publisher use in the EEA, UK and Switzerland. Check the current Google policy and the CMP product scope before launch. Configure consent messages, vendor purposes, regional handling, withdrawal entry point and required privacy signals. This local preference UI is not certified and does not issue a TC string. A CMP configuration needs network validation and production review.

## Affiliate behaviour

Automatic capture and load are gated by the affiliate choice. Reject and withdrawal remove attribution and visitor records. A referral carried in the current signup URL can be captured after an affirmative choice. Do not backfill pre-consent click events. Manual referral entry remains available as a deliberate user request. Check expiry and complete-conversion cleanup.

## Install bridge

web/app_install.js captures beforeinstallprompt before Flutter bootstrap, prevents the default browser promotion, stores the event and exposes snapshot, subscribe, prompt and dismiss methods. A direct user action calls prompt; each event is consumed once. appinstalled or standalone display confirms installed state. Seven-day dismissal is remembered when storage is available, and in-memory dismissal still works when it is blocked. Manual instructions cover browsers without the event.

## Consent test matrix

Verify no optional activity before a choice; equal accept/reject access; each category saves independently; personalisation cannot survive advertising rejection; choices survive reload; reject clears referral data; failures display errors and keep optional tracking off; corrupt, future-dated, expired and old-schema values are treated as unknown; closing does not grant consent; links work without sign-in; two browser profiles remain independent.

## Installation test matrix

Verify a late and an early beforeinstallprompt event, direct-button activation, one event consumed once, acceptance, dismissal, exception, appinstalled, standalone mode, blocked storage and a seven-day cooldown. Test desktop Chrome/Edge and manual Safari instructions on real target devices. Browser eligibility can depend on HTTPS, manifest validity, browser heuristics and user settings; a unit test alone does not certify installability.

## Ad rollout acceptance

Verify approved publisher account, active provider disclosures, correct CMP and region configuration, permitted placements, ads.txt where required, no private route scans or sensitive URL data, no ads on blocked or unknown entitlements, no requests after withdrawal, mobile layout and accessible ad labels. Monitor invalid traffic and use provider-supported testing; never click live ads to test revenue.

## Documentation and versioning

generate_documents.py and publication_expansion.py produce Word, Markdown and assets/legal/publication_library.json from a shared source. The app reads the JSON bundle, so policy content is available without a document download. Policies and guides carry their current update date. Keep accepted versions and publication history aligned with the service. Bump consent schema when new purposes require a new choice, archive old policy versions and record the build and approval owner.

## Publication blockers

Complete registered legal identity/address and grievance contact, retention schedule, processor register, terms venue/liability review, payment promises and affiliate tax/rate reconciliation. Configure support delivery and Google AdSense/CMP before describing them as live. Confirm the actual operating arrangements and obtain appropriate legal review for material legal changes. The current work implements product controls and user-facing policy content; it does not certify legal compliance or activate revenue.

## Reference sources

Reviewed 9 November 2026: Google publisher CMP requirements https://support.google.com/adsense/answer/13554116 ; Google partner-site privacy https://policies.google.com/technologies/partner-sites ; Google ads technologies https://policies.google.com/technologies/ads ; MDN installation event https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeinstallprompt_event ; web.dev installation guide https://web.dev/learn/pwa/installation-prompt ; ICO storage and access guidance https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/guidance-on-the-use-of-storage-and-access-technologies/ . Recheck at deployment.
