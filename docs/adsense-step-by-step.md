# Set up Google AdSense on alphajournal

A practical walkthrough for the free-plan integration in this project. Updated 10 November 2026.

**Start with ads disabled.** First connect and verify your domain. After Google approves the site, finish the consent integration and enable the placements. You do not need to rebuild the ad containers.

## What you need

- Access to your Google AdSense account and the Cloudflare account hosting `alphajournal.in`.
- This project on your computer, with Flutter, Python 3, Node.js and npm installed.
- Your real AdSense publisher ID, five Display ad unit IDs, and a working certified consent management platform (CMP) installation.
- An active **free customer** account for testing. Admin, affiliate, paid and signed-out accounts do not receive ads in this implementation.

The existing advertising code is ready for configuration. AdSense account approval, content review and the CMP's provider-specific installation still need to be completed.

## 1. Add the website to AdSense

Open [Google AdSense](https://www.google.com/adsense/) and sign in. In **Sites**, add `alphajournal.in` using the new-site action. Enter the domain, not a profile URL such as `/@dev_admin`.

Choose **Meta tag** as the ownership-verification method. Copy the complete `ca-pub-…` value from the verification tag. This is your publisher ID. Keep the verification screen available; you will return after publishing the files in step 5.

Google supports verification using a meta tag, ads.txt or its script. This project generates the first two without enabling advertising. [Google's site-verification instructions](https://support.google.com/adsense/answer/12169212)

## 2. Create and record the five ad units

In AdSense, open **Ads → By ad unit → Display ads**. Give each unit a recognizable name, then use the save/get-code action. Copy its `data-ad-slot` value into the worksheet below. Its `data-ad-client` value should match your publisher ID. [Google's Display-unit instructions](https://support.google.com/adsense/answer/9274025)

Use **Display** units with **Responsive** selected for all five placements, including the ones in the feed. Feed units fill the post column and reserve 250px height using Google's [expandable-width setup](https://support.google.com/adsense/answer/9183363). Other placements use the dimensions listed in the technical guide. Save the generated code for reference; you only enter the identifiers in this project.

| Suggested unit name | Configuration field | Your numeric slot ID |
| --- | --- | --- |
| AlphaJournal — Feed Inline | `ADSENSE_SLOT_FEED_INLINE` | __________ |
| AlphaJournal — Feed Footer | `ADSENSE_SLOT_FEED_FOOTER` | __________ |
| AlphaJournal — Community Sidebar | `ADSENSE_SLOT_COMMUNITY_RAIL` | __________ |
| AlphaJournal — Article Footer | `ADSENSE_SLOT_ARTICLE_FOOTER` | __________ |
| AlphaJournal — Public Note Footer | `ADSENSE_SLOT_PUBLIC_NOTE_FOOTER` | __________ |

**Publisher ID:** `ca-pub-________________`

If ad-unit creation is unavailable while your account is being activated, leave the slot fields empty, complete domain verification first, and return to this step when AdSense makes the controls available. An empty slot remains disabled.

## 3. Turn Auto ads off

Open the AdSense ad settings for `alphajournal.in`, switch **Auto ads off**, and save/apply the change. This is a requirement of this app's placement design: it keeps Google from adding ads outside the containers and eligibility checks already built into alphajournal. [Google's Auto ads settings](https://support.google.com/adsense/answer/9305577)

Do not paste another global `adsbygoogle.js` script into `web/index.html`. The app loads that library when its account, content and consent checks pass.

## 4. Add the identifiers to the project

Open Terminal and move into the project:

```sh
cd /Users/nitishkumar/Downloads/projects/nk2552003/TradeX
```

Open the existing `.env` file in your editor. It is a hidden file in the project root. Preserve its existing Supabase and other settings. Add or update the following block, with only one entry for each key:

```dotenv
ADSENSE_ENABLED=false
ADSENSE_PREVIEW=false
ADSENSE_PUBLISHER_ID=
ADSENSE_CMP_SCRIPT_URL=
ADSENSE_SLOT_FEED_INLINE=
ADSENSE_SLOT_FEED_FOOTER=
ADSENSE_SLOT_COMMUNITY_RAIL=
ADSENSE_SLOT_ARTICLE_FOOTER=
ADSENSE_SLOT_PUBLIC_NOTE_FOOTER=
```

Fill the publisher and slot fields using your worksheet. The publisher value must start with `ca-pub-` followed by 16 digits. Slot values are numbers. Leave the CMP field blank until step 7. Keep `ADSENSE_ENABLED=false`.

These fields contain public identifiers. Do not enter your Google password, payment details or private API credentials. Do not upload the complete `.env` file to GitHub.

**These are build-time settings.** Changing a Cloudflare Worker runtime variable alone will not update the Flutter application. Run the preparation and build commands whenever these values change.

## 5. Publish the verification files with ads still off

Run these commands one at a time:

```sh
flutter pub get
python3 scripts/prepare_client_config.py
flutter build web --release
npx wrangler whoami
```

If Wrangler reports that you are not authenticated, run:

```sh
npx wrangler login
```

Complete sign-in to the Cloudflare account that owns this website. Then publish the existing Worker:

```sh
npx wrangler deploy
```

The repository uses **Cloudflare Workers with static assets**, so use this deployment command with the existing `wrangler.jsonc`.

The preparation script automatically produces:

| File | Expected result |
| --- | --- |
| `web/index.html` | A `google-adsense-account` meta tag containing your `ca-pub-…` ID |
| `web/ads.txt` | An authorized-seller entry containing the matching `pub-…` ID |
| `assets/config/client.env` | The allowlisted public configuration used by Flutter |

Do not manually replace the application's existing HTML or configuration files with Google's example page.

## 6. Verify the live files and request review

Open [https://alphajournal.in/ads.txt](https://alphajournal.in/ads.txt). It should show a plain-text seller entry in this format, with **your actual digits**:

```text
# Format illustration only — replace YOUR_16_DIGITS with your publisher number.
google.com, pub-YOUR_16_DIGITS, DIRECT, f08c47fec0942fa0
```

It must not show the app's loading page or a 404. You can also check the deployed files in Terminal:

```sh
curl -fsS -D - https://alphajournal.in/ads.txt
curl -fsS https://alphajournal.in/ | rg 'google-adsense-account'
```

The first response should have a successful status, a `text/plain` content type, and the matching seller ID. The second should show your publisher-verification meta tag. [Google's ads.txt guide](https://support.google.com/adsense/answer/12171612)

Return to the AdSense verification screen, verify the site and request review. Leave ads disabled while approval is pending; check the site status in AdSense rather than assuming that a successful deployment means approval.

**Crawler access needs attention in this app.** Public reading routes currently require sign-in and use Flutter rendering. Google must be able to reach and evaluate the content you plan to monetize. Check crawler errors. If applicable, use Google's supported crawler-login setup after account activation. A dedicated account containing no private trading data is preferable to an administrator account. If the current login/rendering cannot support crawling, that needs a separate implementation before these pages can be monetized. [Google's guidance for login-protected pages](https://support.google.com/adsense/answer/161351)

## 7. Configure the consent platform

A CMP is the provider that collects and communicates advertising-consent choices. alphajournal's existing Cookie preferences are an additional control; they do not replace a certified CMP.

In AdSense, **Privacy & messaging** is where you configure Google's consent messages. Review the European regulations message, attach the site, provide the privacy-policy URL, configure choices and publish the message. Configure other applicable regional messages for your audience. Google also supports certified third-party CMPs. [Google's CMP overview](https://support.google.com/adsense/answer/16918505)

For the **current alphajournal adapter**, complete this installation step as well:

1. Obtain your CMP provider's actual installation code and HTTPS script URL.
2. Put its script URL in `ADSENSE_CMP_SCRIPT_URL` if that script performs the complete installation.
3. If the provider requires additional initialization or a locator/bootstrap snippet, have that exact setup added to a first-party file named `web/adsense-cmp.js`. Then set:

```dotenv
ADSENSE_CMP_SCRIPT_URL=https://alphajournal.in/adsense-cmp.js
```

**That file is not supplied automatically.** Use the URL above only after creating it with the provider's required installation code. It must return JavaScript, not the app's fallback HTML.

The CMP must expose the TCF `__tcfapi` interface and deliver a completed consent/applicability result before the adapter requests an ad. Publishing a message in the AdSense dashboard alone does not demonstrate that this integration is installed. If the provider's default setup waits for the advertising library to load first, it can conflict with this app's consent-first loading order; obtain a supported independent CMP bootstrap or have the integration adapted. Do not bypass the checks to resolve that dependency.

This installation is provider-specific. Keep live ads off until the selected CMP works with this loading order. The existing adapter also waits for an explicit non-GDPR applicability result outside the covered regions; it does not infer permission from a visitor's country.

## 8. Preview placements and finish the launch checklist

To view the containers without contacting Google, run:

```sh
flutter run -d chrome -t lib/main_ads_preview.dart
```

Resize the window and switch between free and paid mode. This preview confirms layout only; it does not test Google approval or the actual CMP.

To preview boxes inside the normal app, set `ADSENSE_PREVIEW=true` and keep `ADSENSE_ENABLED=false` in `.env`. Run `python3 scripts/prepare_client_config.py`, fully stop your running Flutter session, then run `flutter run -d chrome`. Hot reload alone does not reload these settings. Open **Trader workspace → Community → For you**: even an empty or short feed now shows a placeholder. Desktop feed/explore pages also show the sidebar box. Article and public read-only note footers preview even with short text. Admin and demo accounts can use these development placeholders; screen-width and public-surface requirements still apply. Dashboard/profile pages and private notes have no ad placements. Release builds ignore the preview flag. See the [preview instructions](adsense-setup.md#preview-the-containers-without-google) for details.

| Placement | When the live app can show it |
| --- | --- |
| Feed inline | After For You posts 5, 15, 25, etc., when all loaded posts are public and approved |
| Feed footer | After For You posts 10, 20, 30, etc., under the same conditions |
| Community sidebar | Desktop public feed/explore, sufficient width and at least five approved public posts |
| Article footer | A first-party `alphajournal` article with at least 1,200 characters of summary text |
| Public note footer | A public, read-only note of at least 300 words opened in public context |

Each five-post position makes its own ad request, alternating the two feed unit IDs. Google decides which creative to show; a unique creative at every position is not guaranteed. Messages, AI Assistant and Writing Desk also show **non-Google promotion previews** while `ADSENSE_PREVIEW=true`. Those private-screen previews cannot serve AdSense and disappear in production; no additional Google slot IDs are needed for them. See the [placement guide](adsense-setup.md#preview-the-containers-without-google).

Before activating:

- [ ] AdSense reports the site ready, and ownership / ads.txt checks succeed.
- [ ] The content to be monetized is original or properly authorized, policy-reviewed and crawler-accessible.
- [ ] Auto ads are off; only the five manual Display units are configured.
- [ ] The selected CMP is installed and works with the consent-first adapter.
- [ ] Public privacy, cookie, advertising and contact pages are accessible.
- [ ] The policy sources that currently describe AdSense as planned/inactive are updated to match the launch, and the publication library is regenerated.
- [ ] Free and paid preview layouts behave as expected.

Policy sources live in `docs/publication_pack/publication_policies.py` and `docs/publication_pack/publication_expansion.py`; generation is handled by `docs/publication_pack/generate_documents.py`. The changes should describe the actual provider and deployment, rather than merely deleting the word “planned.” See the [publication-pack instructions](publication_pack/README.md).

## 9. Enable ads and deploy again

When the checklist is complete, change only the activation flag in the advertising block:

```dotenv
ADSENSE_ENABLED=true
```

Keep the real publisher, slot and CMP settings in place, then run:

```sh
python3 scripts/prepare_client_config.py
flutter build web --release
npx wrangler deploy
```

After deployment, use an active **free customer** account. In Help or settings, open Cookie preferences and save advertising permission. Complete the CMP choice when presented. Visit an eligible page with enough public content and scroll to the placement.

AdSense may return no inventory even when the integration is working. Do not click your own ads to test delivery. Check account diagnostics, browser network requests and the following behavior instead:

| Check | Expected behavior |
| --- | --- |
| Paid, admin or affiliate account | No ad placements |
| Private writing, messages, billing or settings | No ads |
| Advertising rejected or consent unknown | No ad request |
| Consent withdrawn or access becomes ineligible | Pending requests stop; an already loaded SDK is unloaded through a page reload |
| Ad blocker, failed SDK load or explicitly unfilled unit | Content remains usable; failed/unfilled ad unit collapses |

## 10. Troubleshoot or turn ads off

| Symptom | What to check |
| --- | --- |
| “Not authenticated” during deploy | Run `npx wrangler login` with the correct Cloudflare account. |
| Publisher configuration error | Copy the complete `ca-pub-` ID with 16 digits; do not use a slot ID here. |
| ads.txt contains only comments | The preparation step did not receive a publisher ID. Fill it, regenerate, rebuild and deploy. |
| ads.txt shows the app instead of text | Confirm `build/web/ads.txt` exists and the correct Worker/assets were deployed. |
| AdSense cannot verify the site | Compare the live meta tag and seller entry with your account's ID. |
| Preview works but no live ads appear | Preview is intentionally offline. Check activation, site approval, actual IDs, free-customer eligibility and both consent layers. |
| No live ads appear while using `dev_admin` | An admin account is excluded from live ads even if its plan value is free. Use a free customer test account. Development placeholders work in Trader view with preview enabled. |
| No preview boxes in the normal app | Check `ADSENSE_PREVIEW=true` in `.env` and the generated `assets/config/client.env`, restart Flutter, and open Community → For you in Trader view. Dashboard/profile pages have no placements. |
| CMP never appears | Verify the installer URL returns the real script, its bootstrap is complete, and it can initialize before AdSense. |
| CMP succeeds but ads stay blocked | Verify its TCF event reports a completed decision/applicability result and the relevant Google/storage consent. |
| A particular slot is absent | Check its content/viewport conditions above. An empty slot ID deliberately disables that placement. |
| Configuration changed but the site did not | Regenerate the client settings, rebuild and redeploy; runtime settings alone do not change the Flutter bundle. |
| Google reports crawl/content issues | Resolve the underlying public-content or login/rendering issue before enabling that placement. |

To stop future delivery from the rebuilt app, set:

```dotenv
ADSENSE_ENABLED=false
```

Then regenerate, rebuild and deploy using the same three commands. Already open tabs may need to reload to pick up the new build. A visitor can immediately withdraw their own optional advertising choice through Cookie preferences.

For architecture details and the complete configuration reference, see [Free-plan AdSense setup](adsense-setup.md).
