# AlphaJournal billing, moderation, and publication handoff

## Current implementation

The Flutter client reads the published pricing catalogue from `pricing_catalogues` in Supabase. The published JSON supplies card prices, comparison rows, feature text, and enforced quota values. The current customer-facing plans are **Free**, **Basic**, and **Pro**, mapped to backend tiers `free`, `premium`, and `enterprise`. Baseline preview prices are ₹0, ₹299/month, and ₹499/month. Basic and Pro remain `is_purchasable: false`; those prices are product previews, not an active production checkout offer. Configured clients show a load error if the catalogue is unavailable instead of inventing prices.

The client and database contract enforce limits for saved notes, journal entries, live playbooks, watchlists, alerts, Community actions, and monthly AI requests. Full Market Intelligence, Private Messages, and advanced calculators require Basic or Pro. Free users receive only the bounded market/news/instrument preview used by Community and must not initialize paid market or message queries. Normal users cannot change their own trusted role or effective subscription tier. Complete staging RLS, direct-route, direct-RPC, downgrade, expiry, and provider-event tests before treating the policy as end-to-end proof.

On Android and iOS, `RevenueCatBilling` initializes from the publishable API key in `.env`, identifies the signed-in Supabase UUID, retrieves offerings and customer info, opens the paywall for entitlement `alphajournal_pro`, restores purchases, and opens Customer Center. The mobile purchase UI requires current offering packages for `monthly` and `annual` only. Paid access in Supabase changes only when the server webhook reconciles the current RevenueCat subscriber record. No client callback can mark a subscription paid. Debug builds use `REVENUECAT_TEST_API_KEY`; release builds require their platform's production public key. The test key cannot be used for a Play Store or App Store launch.

Web/desktop Razorpay checkout preparation currently uses the legacy function name `create-business-checkout` together with `razorpay-webhook`. That internal name does not change the public Free/Basic/Pro plan model. The published catalogue must keep Basic and Pro unavailable until production plan IDs, server secrets, function deployment, webhook signatures, idempotency, replay handling, price readback, cancellation, expiry, and refund behavior are verified. A Razorpay Key ID is public configuration; it is never proof that checkout is safe to enable. Only a verified provider event and trusted server reconciliation may grant paid access.

## Obtain the missing test credentials

Use **Test Mode** throughout these steps. Keep the existing public Razorpay Key ID and RevenueCat Test Store SDK key in the ignored Flutter `.env`; no additional public key needs to be pasted into chat.

1. **Razorpay API Key Secret:** Sign in to the Razorpay Dashboard, switch to **Test Mode**, then open **Account & Settings → API Keys → Generate Key**. Copy the **Key Secret** when it appears; Razorpay does not show the same secret again. The Key ID should correspond to the existing test Key ID. Store the secret only in Supabase Edge Function Secrets as `RAZORPAY_SECRET_KEY` (the functions also accept `RAZORPAY_KEY_SECRET`) and store the matching ID there as `RAZORPAY_KEY_ID`. Never put either secret variable in the root Flutter `.env` asset.
2. **Razorpay paid plans:** In Test Mode open **Subscriptions → Plans → New Plan**. Create the exact INR products approved for the Basic/Pro rollout and ensure their amounts match the published Supabase catalogue. The existing Edge Function still reads legacy environment names such as `RAZORPAY_BUSINESS_MONTHLY_PLAN_ID` and `RAZORPAY_BUSINESS_YEARLY_PLAN_ID`; treat those as compatibility names until a separately reviewed server migration replaces them. Razorpay plans cannot be edited after creation, so verify amount, interval, currency, tax handling, and mapped AlphaJournal tier before saving.
3. **Razorpay Affiliate Referral Offers (Month 1 Monthly Discounts):** In Razorpay Dashboard open **Subscriptions → Offers on Subscriptions → Create New Offer** and create two single-cycle (`1` cycle) flat-discount offers enabled for UPI, Cards, and NetBanking:
   - **Basic Monthly Referral Offer (`₹299 → ₹239` Month 1):** Flat **₹60** off, 1 billing cycle → store generated `offer_...` ID in Supabase Edge Function Secrets as `RAZORPAY_AFFILIATE_BASIC_MONTHLY_OFFER_ID`.
   - **Pro Monthly Referral Offer (`₹499 → ₹399` Month 1):** Flat **₹100** off, 1 billing cycle → store generated `offer_...` ID in Supabase Edge Function Secrets as `RAZORPAY_AFFILIATE_PRO_MONTHLY_OFFER_ID`.
   - Annual subscriptions already reflect the 20% discounted rate (₹239/mo Basic, ₹399/mo Pro) and do not stack an extra offer, while still attributing the conversion to the partner.
   - Affiliate commissions are credited server-side by `finalize_affiliate_referral_conversion`: **₹10 INR** per verified paid Basic/Pro user for conversions #1–50, **₹30 INR** per verified paid user from #51 onward, and **complimentary AlphaJournal Pro unlocks automatically ONLY at 50 verified paid Basic/Pro referrals** (auto-revoked on refund reversals below 50). Affiliates are strictly blocked from redeeming their own or any other affiliate's referral/coupon codes.
4. **Razorpay webhook secret:** Open **Account & Settings → Webhooks** in Test Mode, create a webhook for the deployed Razorpay Edge Function URL, select subscription activation, charge, cancellation, failure, and refund (`refund.processed` / `payment.refunded`) events, and set a new long random webhook secret. Save the same value in Supabase Edge Function Secrets as `RAZORPAY_WEBHOOK_SECRET`. This is a secret **you create** in the webhook form, separate from the API Key Secret. A webhook must validate `X-Razorpay-Signature` against the raw body before changing access.
4. **RevenueCat server API key:** In the RevenueCat project open **Project settings → API keys → New secret API key**. Select **v2** and grant read permissions for entitlements, customer active entitlements, and customer subscriptions. Store it as `REVENUECAT_SECRET_API_KEY` in Supabase Edge Function Secrets, and set `REVENUECAT_PROJECT_ID` to the project ID from RevenueCat. The supplied `test_...` SDK key stays in Flutter and cannot replace this server key. The separate v1 key is valid but the webhook uses v2.
5. **RevenueCat webhook token:** Create a long random token yourself. Store it as `REVENUECAT_WEBHOOK_TOKEN` in Supabase Edge Function Secrets. In **RevenueCat → Integrations → Webhooks**, set the deployed `revenuecat-webhook` URL and Authorization header to `Bearer <the same token>`. Select sandbox events for test purchases.
6. **Supabase access:** Sign in to the Supabase project Dashboard with Owner or Administrator access. Open **Edge Functions → Secrets**, add the server values above, and save. Supabase provides `SUPABASE_URL` and a privileged server key to deployed functions; never put that key into the Flutter `.env`. Apply the database migrations and pricing seed in the Dashboard SQL Editor, then deploy the Edge Functions. A public/anon key cannot perform these steps.

After the server code and functions are deployed, run test transactions and verify the **same signed-in Supabase user** gains or loses the appropriate tier only after the verified provider event. Test keys and test products never enable real-money production billing. For release, repeat setup with separate live Razorpay keys/plans/webhook and production platform-specific RevenueCat public keys and store products.

Deploy `create-business-checkout` with normal Supabase JWT verification and `razorpay-webhook` with JWT verification disabled, because Razorpay authenticates through the webhook HMAC. Keep Basic and Pro disabled until purchase, renewal, cancellation, expiry, refund, replay, out-of-order delivery, downgrade, and database readback tests pass for the same signed-in user. A configuration or plan-price mismatch must fail closed.

## RevenueCat setup

1. In RevenueCat, create entitlement `alphajournal_pro`.
2. In Google Play Console and App Store Connect, create distinct products for monthly and yearly subscriptions. Enter the exact store product IDs in RevenueCat; product ID strings alone are not enough until the stores approve and return the products.
3. Attach both products to `alphajournal_pro`, then add `monthly` and `annual` packages to the **current offering**. Build a paywall for that offering and configure Customer Center.
4. Set publishable keys in the local ignored `.env`: `REVENUECAT_TEST_API_KEY` for development, `REVENUECAT_ANDROID_API_KEY` and `REVENUECAT_IOS_API_KEY` for release. `RAZORPAY_TEST_KEY_ID` is a public identifier only.
5. Configure `REVENUECAT_WEBHOOK_TOKEN` and `REVENUECAT_SECRET_API_KEY` as Supabase Edge Function secrets, together with the project's service role key. Set RevenueCat's webhook Authorization header to `Bearer <REVENUECAT_WEBHOOK_TOKEN>`. Deploy `supabase/functions/revenuecat-webhook` without JWT verification because RevenueCat is not a Supabase user. Do not use the anon key for this function.
6. Test purchase, restore, renewal, cancellation, expiry, refund, and account switching. Verify `subscriptions`, `profiles.subscription_tier`, and the limit trigger after each event. Record the event ID and do not publish until readback passes.

Install the locked dependencies with `flutter pub get`. The code uses the SDK methods `Purchases.configure`, `Purchases.logIn`, `Purchases.getCustomerInfo`, `Purchases.getOfferings`, `RevenueCatUI.presentPaywallIfNeeded`, `Purchases.restorePurchases`, and `RevenueCatUI.presentCustomerCenter`. Android `MainActivity` extends `FlutterFragmentActivity` for paywall UI.

The webhook currently reconciles the RevenueCat subscriber on each event. It returns an error when server secrets, profile, or RevenueCat API state are missing, which causes RevenueCat to retry. The server must be deployed and exercised in test mode before paid plans can be advertised as available. Reconcile existing purchasers once at deployment because a webhook only processes delivered events.

## Supabase deployment and verification

1. Back up the live database and inspect the current migration ledger. Apply migrations through `033` in order, then `034_public_pricing_and_community_review.sql`, `035_community_comment_reactions.sql`, and `036_billing_providers_and_user_quota.sql`. The `029_storage_buckets_setup.sql` file is separate from this migration.
2. Apply `database/rls_policies.sql` after migrations as the repository instructs. It contains the matching approved-only community read policies.
3. Run `database/seeds/04_pricing_catalogue.sql` with an authenticated database administrator. This publishes the catalogue used by the app. The Supabase anon key cannot do this.
4. From an anon session, verify exactly one published pricing row is readable. From a normal user session, verify pricing writes, paid-tier updates, and direct subscription writes are denied. Create a post and comment and verify a different normal user cannot see them. Approve each from Admin Publishing, then verify public visibility. Reject another and verify it remains hidden.
5. Use test emails you control with Supabase Auth. Create one customer and one admin only through the administrator console or privileged tooling. Never create a test admin by writing an unverified role in the client. Confirm role changes, moderation and subscription writes through the actual deployed RLS policies.

The public Supabase key may read only the published rows allowed by grants and RLS. It cannot migrate tables, publish trusted catalogue changes, configure Edge Function secrets, or create verified admin users. Apply migrations and deploy functions through an authenticated project dashboard or scoped CLI session. Do not put server secret keys in the Flutter `.env`, the asset bundle, chat, screenshots, logs, or source control.

Do not record credential values or unrepeatable claims that a secret “works” in this document. Put dated, sanitized verification evidence in the private release record or deployment issue: provider mode, product/package identifiers, event IDs, webhook HTTP results, trusted entitlement readback, database migration/advisor output, and rollback owner. Never paste the underlying key, token, payment data, or customer record.

## App store release gate

Current code is **not ready to upload as a production paid app**. Android, iOS, and macOS use `com.nk2552003.alphajournal`, but Android release signing is not final; production RevenueCat/store products and Razorpay webhooks are not fully verified; paid catalogue rows remain unavailable; and publication documents still require owner/legal review and final business/contact details. Complete Google Play Data Safety, Apple privacy details, privacy/account-deletion URLs, content rating, screenshots, support contact, financial-feature declarations, billing review, signed internal tracks, restoration tests, and staged rollout evidence before production release. The documents in `docs/publication_pack` are review drafts, not legal advice or a guarantee against claims.

## Official references

- RevenueCat Flutter installation: https://www.revenuecat.com/docs/getting-started/installation/flutter
- RevenueCat paywalls: https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls
- RevenueCat Customer Center: https://www.revenuecat.com/docs/tools/customer-center/customer-center-flutter
- RevenueCat Test Store: https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store
- RevenueCat webhooks: https://www.revenuecat.com/docs/integrations/webhooks
- Razorpay API keys: https://razorpay.com/docs/api/payment-links/v1/
- Razorpay plans: https://razorpay.com/docs/api/payments/subscriptions/create-plan/
- Razorpay webhook validation: https://razorpay.com/docs/webhooks/validate-test/
- RevenueCat API keys: https://www.revenuecat.com/docs/projects/authentication
- Supabase Edge Function secrets: https://supabase.com/docs/guides/functions/secrets
- Razorpay security checklist: https://security.razorpay.com/security/checklist/
