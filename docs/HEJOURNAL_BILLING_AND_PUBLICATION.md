# hejournal.in billing, moderation, and publication handoff

## Current implementation

The Flutter client reads the published pricing catalogue from `pricing_catalogues` in Supabase. The published JSON supplies card prices, comparison rows, feature text, and the four enforced quota values. The Free, Pro, and Business cards map to the existing backend tiers `free`, `premium`, and `enterprise`; Business is the customer-facing name for the existing enterprise tier. An administrator can edit and publish the catalogue in Admin Publishing. Until the live catalogue is published, configured clients show a load error instead of invented prices.

The client and migration enforce limits for saved notes, journal entries, live playbooks, and monthly AI requests. The migration also prevents a normal user from changing their own role or subscription tier. Community posts and comments enter `pending`; public reads require `approved`, and admins have a review queue. Apply the migration and the final RLS policy file before trusting these guarantees in a deployed environment.

On Android and iOS, `RevenueCatBilling` initializes from the publishable API key in `.env`, identifies the signed-in Supabase UUID, retrieves offerings and customer info, opens the paywall for entitlement `tradex_pro`, restores purchases, and opens Customer Center. The mobile purchase UI requires current offering packages for `monthly`, `annual`, and `lifetime`. Paid access in Supabase changes only when the server webhook reconciles the current RevenueCat subscriber record. No client callback can mark a subscription paid. Debug builds use `REVENUECAT_TEST_API_KEY`; release builds require their platform's production public key. The test key cannot be used for a Play Store or App Store launch.

Desktop Business checkout is currently disabled. The supplied Razorpay value is a **test key ID**, not a secret, and cannot create or verify a charge. To activate a direct Business purchase, create a server-side Razorpay subscription/order flow, verify Razorpay's callback/webhook signature and final payment state, and then write `subscriptions` from a privileged backend. Never enable the Business paid button merely because the public key ID exists.

## RevenueCat setup

1. In RevenueCat, create entitlement `tradex_pro`.
2. In Google Play Console and App Store Connect, create distinct products for monthly, yearly, and lifetime. Enter the exact store product IDs in RevenueCat; product ID strings alone are not enough until the stores approve and return the products.
3. Attach all three products to `tradex_pro`, then add `monthly`, `annual`, and `lifetime` packages to the **current offering**. Build a paywall for that offering and configure Customer Center.
4. Set publishable keys in the local ignored `.env`: `REVENUECAT_TEST_API_KEY` for development, `REVENUECAT_ANDROID_API_KEY` and `REVENUECAT_IOS_API_KEY` for release. `RAZORPAY_TEST_KEY_ID` is a public identifier only.
5. Configure `REVENUECAT_WEBHOOK_TOKEN` and `REVENUECAT_SECRET_API_KEY` as Supabase Edge Function secrets, together with the project's service role key. Set RevenueCat's webhook Authorization header to `Bearer <REVENUECAT_WEBHOOK_TOKEN>`. Deploy `supabase/functions/revenuecat-webhook` without JWT verification because RevenueCat is not a Supabase user. Do not use the anon key for this function.
6. Test purchase, restore, renewal, cancellation, expiry, refund, lifetime, and account switching. Verify `subscriptions`, `profiles.subscription_tier`, and the limit trigger after each event. Record the event ID and do not publish until readback passes.

Install/refresh dependencies with `flutter pub add purchases_flutter purchases_ui_flutter`. The code uses the SDK methods `Purchases.configure`, `Purchases.logIn`, `Purchases.getCustomerInfo`, `Purchases.getOfferings`, `RevenueCatUI.presentPaywallIfNeeded`, `Purchases.restorePurchases`, and `RevenueCatUI.presentCustomerCenter`. Android `MainActivity` extends `FlutterFragmentActivity` for paywall UI.

The webhook currently reconciles the RevenueCat subscriber on each event. It returns an error when server secrets, profile, or RevenueCat API state are missing, which causes RevenueCat to retry. The server must be deployed and exercised in test mode before paid plans can be advertised as available. Reconcile existing purchasers once at deployment because a webhook only processes delivered events.

## Supabase deployment and verification

1. Back up the live database and inspect the current migration ledger. Apply migrations through `033` in order, then `034_public_pricing_and_community_review.sql`. The `029_storage_buckets_setup.sql` file is separate from this migration.
2. Apply `database/rls_policies.sql` after migrations as the repository instructs. It contains the matching approved-only community read policies.
3. Run `database/seeds/04_pricing_catalogue.sql` with an authenticated database administrator. This publishes the catalogue used by the app. The Supabase anon key cannot do this.
4. From an anon session, verify exactly one published pricing row is readable. From a normal user session, verify pricing writes, paid-tier updates, and direct subscription writes are denied. Create a post and comment and verify a different normal user cannot see them. Approve each from Admin Publishing, then verify public visibility. Reject another and verify it remains hidden.
5. Use test emails you control with Supabase Auth. Create one customer and one admin only through the administrator console or privileged tooling. Never create a test admin by writing an unverified role in the client. Confirm role changes, moderation and subscription writes through the actual deployed RLS policies.

The public Supabase key presently available in the checkout can read published rows but cannot migrate tables, insert the seed, configure Edge Function secrets, or create verified admin users. Those steps require a privileged database connection or authenticated Supabase project dashboard. Do not put service role keys in `.env`, the Flutter asset bundle, chat, or source control.

## App store release gate

Current code is **not ready to upload as a production paid app**. The Android package and iOS/macOS bundle IDs still contain `com.example.tradex`; the Android release build still uses debug signing; production RevenueCat keys and store products are missing; the live catalogue and webhook have not been deployed and verified; the legal Word documents still contain business identity/contact placeholders. Complete the Google Play Data Safety, privacy URL, account deletion URL, content rating, screenshots, support contact, financial feature declarations, store billing review, and internal testing track before production release. The 15 Word documents in `docs/publication_pack` are review drafts, not a guarantee against legal claims.

## Official references

- RevenueCat Flutter installation: https://www.revenuecat.com/docs/getting-started/installation/flutter
- RevenueCat paywalls: https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls
- RevenueCat Customer Center: https://www.revenuecat.com/docs/tools/customer-center/customer-center-flutter
- RevenueCat Test Store: https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store
- RevenueCat webhooks: https://www.revenuecat.com/docs/integrations/webhooks
- Razorpay security checklist: https://security.razorpay.com/security/checklist/
