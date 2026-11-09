# Cookie and Similar Technologies Policy

Policy | Updated 2026-11-09

This policy explains essential and optional browser or device storage, how you control it, and how the planned Google AdSense service relates to those choices.

## What these technologies do

Cookies are small browser records that may accompany matching web requests. Local storage, IndexedDB, app preferences and cache storage can also hold information on a device. Scripts, pixels and identifiers can transmit information without a conventional cookie. Our optional-purpose choices apply to these technologies as relevant, rather than only to files named cookies. Effective date: 9 November 2026.

## Essential storage

Essential records support sign-in, account security, session continuity and settings you request. The preference record also remembers your cookie decision so you are not asked on every visit. Rejecting optional tracking does not disable necessary account functions. Browser-level blocking of all site storage can nevertheless interfere with sign-in and saving preferences. Clearing storage may sign you out or remove unsynchronised work.

## Analytics

Optional analytics means measurement of how the service is used when an analytics integration is enabled. The choice starts off and is separate from advertising. A saved permission does not itself activate a provider. Necessary operational security and error handling are distinct from optional marketing or usage measurement. We will disclose material optional integrations before enabling them.

## Advertising and personalised ads

Google AdSense is planned for the free version and is not active in this release. Advertising permission covers optional ad delivery, measurement and associated storage when enabled. Personalised ads require an additional choice and cannot remain on while advertising is off. Non-personalised advertising can still use identifiers, IP information or storage; it is not automatically exempt from consent. See https://policies.google.com/technologies/partner-sites and https://policies.google.com/technologies/ads for Google information.

## Automatic affiliate attribution

With the affiliate choice enabled, a referral visit can store a code, campaign and capture time in affiliate_attribution_v1, with a random visitor identifier in affiliate_visitor_v1. Attribution is valid for less than 30 days and is removed when an expired or invalid record is encountered, after conversion cleanup, or when this choice is withdrawn. Campaign click reporting is also gated by this choice. A code you deliberately enter in signup is a separate user-requested action. Rejecting automatic attribution can prevent automatic commission credit.

## The local consent record

alphajournal_consent_v1 contains the preference schema version, UTC saved time and the analytics, advertising, personalisation and affiliate choices. It is stored through SharedPreferences, normally under a flutter. prefix on web. It contains no ad visitor identifier. Its validity is 180 days from saving; absent, invalid, future-dated, expired or older-schema records leave optional processing off. This period is a product setting, not a claim about a universal legal limit.

## Accept reject and change choices

The initial notice offers Accept optional, Reject optional and Manage choices. Manage choices provides separate switches and Save choices. Closing or continuing to browse is not acceptance. Reopen Cookie preferences through Help and policies, Privacy settings or available footer links. Save all optional switches off or choose Reject optional to withdraw. Your choices apply to the current browser or device, not automatically to all other devices or accounts.

## Save failures and withdrawal

If a choice cannot be saved, the interface explains the problem and keeps optional processing off in the current session. You may retry after allowing device storage or continue with essential storage. A failed save is not reported as success. Withdrawal stops future optional activity from connected integrations and removes first-party optional attribution records; it does not recall data already sent or automatically erase historical billing and security records.

## Installation preference

alphajournal_install_dismissed_v1 stores the time you dismissed the browser installation suggestion. It suppresses automatic suggestions for seven days and may physically remain until overwritten or cleared. It is not an advertising identifier. Browser-managed installed state is separate. Installing or uninstalling the web app does not grant or withdraw cookie permission.

## Third parties and regional choices

Before advertising is enabled, applicable provider and regional controls must also be satisfied. Google requires a certified consent management platform for covered publisher uses in the EEA, UK and Switzerland. This local preference screen is not a certified CMP and does not generate a TCF consent string. An unknown or missing required permission must not be treated as agreement. Third-party cookies cannot always be removed by our domain; use browser site-data controls and the provider’s privacy controls as needed.

## Inventory changes and contact

The Storage Vendor and Retention Register describes known first-party records and the planned provider. Active vendor records and durations depend on the deployed integration and must be disclosed when enabled; example vendor cookie names are not presented as observed facts. We will update this policy for material changes and renew choices where required. Contact h82292245@gmail.com for questions or requests concerning previously collected information.
