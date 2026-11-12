# Free-plan AdSense setup

**First-time setup:** Follow the [step-by-step walkthrough](adsense-step-by-step.md) for the account screens, ID worksheet, two deployments and troubleshooting.

The web app now has manual ad placements, free-account checks, optional-consent checks, a certified-CMP adapter, a lazy-loading AdSense adapter, and public site-verification / ads.txt generation. Live advertising defaults OFF. No publisher ID or slot number has been invented. Native Flutter apps do not load this integration.

## Placement inventory

| Placement | Where it appears | Space reserved | Configuration |
| --- | --- | --- | --- |
| Feed inline | For You, after posts 5, 15, 25, etc. | Full post-column width × 250px | `ADSENSE_SLOT_FEED_INLINE` |
| Feed footer | For You, after posts 10, 20, 30, etc. | Full post-column width × 250px | `ADSENSE_SLOT_FEED_FOOTER` |
| Community rail | Desktop public feed/explore sidebar with sufficient approved content | 300×250 | `ADSENSE_SLOT_COMMUNITY_RAIL` |
| Article footer | Below substantial first-party alphajournal article text | 728×90 wide; 300×250 / 250×250 narrow | `ADSENSE_SLOT_ARTICLE_FOOTER` |
| Public note footer | Below a public, read-only note of at least 300 words | Same responsive container | `ADSENSE_SLOT_PUBLIC_NOTE_FOOTER` |

Create **Display** ad units with **Responsive** selected. Feed containers follow Google's [expandable-width, fixed-height pattern](https://support.google.com/adsense/answer/9183363): the ad uses 100% of the post column and reserves 250px height. Other placements retain the explicit sizes above. Units never clip, overlay or scale a creative. Feed ads alternate the two configured slot IDs every five posts. Each occurrence has an independent request, keyed by a non-identifying position number; scrolling or resizing does not request it again. Google selects the creative, so different requests do not guarantee different advertisers. Scrolling a slot into view triggers the initial request. Empty/loading/private/unapproved feeds have no live ad. Unfilled units collapse after Google's `data-ad-status=unfilled` signal. Blocked script loads collapse without breaking content.

No live ads are installed in login/signup, private notes or writing editors, journal/balance dashboards, messaging, copilot, billing, settings, administration, referrals, security, deletion or empty/error screens. Paid or unknown account access suppresses every live placement. News summaries from other publishers are not monetized; minimum length is only a layout safeguard, not a substitute for editorial review or permission to monetize content.

## Preview the containers without Google

```sh
flutter run -d chrome -t lib/main_ads_preview.dart
```

The gallery shows each reserved area and a free/paid toggle without initializing any advertising or CMP SDK. Resize it to check narrow mobile, tablet and desktop layouts. The application also recognizes `ADSENSE_PREVIEW=true` only in non-release builds; production builds cannot enable that flag.

To show placeholders in the normal app, set these values in the project-root `.env`:

```dotenv
ADSENSE_PREVIEW=true
ADSENSE_ENABLED=false
```

Then regenerate the bundled configuration and start a fresh debug session:

```sh
python3 scripts/prepare_client_config.py
flutter run -d chrome
```

Fully stop and restart any running Flutter session; hot reload does not reload this configuration. The backend-free `lib/main_frontend_preview.dart` entry point reads the same settings. No publisher ID, slot IDs or advertising consent are needed for placeholders, and preview mode does not initialize Google or the CMP. Set `ADSENSE_PREVIEW=false` and regenerate the configuration when finished.

In the normal app, switch to the Trader workspace and open **Community → For you**. Development preview works with any account tier, including an admin using Trader view. For an empty feed or fewer than five posts, a sample box appears below the header. Once five posts exist, boxes appear after every five posts (5, 10, 15, etc.), numbered in the preview and alternating the two feed units. The desktop feed/explore sidebar also shows a box without requiring five approved posts.

Open a news article to see its footer, or a public note in read-only public context to see the note footer. Development placeholders do not require the live minimum text lengths, post approval or first-party article publisher. Private notes, editors, dashboard/profile pages and administrative pages remain without placements. Width requirements still apply (at least 250px for an inline unit, 300px for the desktop rail). Live ads continue to require all content, account and consent checks listed above. Use the gallery to see every container together.

**Other product screens:** Messages has a promotion preview below the inbox list, AI Assistant has one above the chat, and Writing Desk has one above Quick Links. These are non-interactive, development-only spaces for potential house promotions; they have no AdSense unit IDs and cannot mount a Google ad. They disappear when preview is off and in release builds. Google [excludes private communication screens](https://support.google.com/publisherpolicies/answer/48182); the AI chat and private workspace also remain outside the public-content AdSense integration. Actual house-promotion content/provider setup is separate.

## Connect your own account

1. In AdSense, add `alphajournal.in`. Complete the account, payee and site-review requirements in your account. Review all monetized community/public research content against Google's publisher policies and keep moderation active. Provide substantial original content and working public navigation, contact and policy pages; code readiness does not guarantee approval.
2. Copy your publisher ID (`ca-pub-` plus 16 digits). Create the five **Display** units in the table and copy their numeric slot IDs.
3. **Turn Auto ads OFF for this site in AdSense**, including anchors, vignettes and page-level automatic placements. This is essential: automatic placements could bypass the app's approved surfaces and free-tier rules.
4. Configure a Google-certified CMP integrated with IAB TCF. In AdSense, Privacy & messaging offers Google's CMP. Configure applicable regional messages, withdrawal choices and other regional privacy messages for your audience. Use the exact installation script URL supplied by your CMP in `ADSENSE_CMP_SCRIPT_URL`; if its installation requires a bootstrap/locator snippet, put that snippet in a first-party `web/adsense-cmp.js` wrapper and use its absolute HTTPS URL. The wrapper must install the provider's documented code and `__tcfapi`, not invent a consent string or replace a certified CMP. The app's existing cookie switches are an additional gate, not a certified CMP.
5. Add your public identifiers to the local `.env` or hosting build environment:

```dotenv
ADSENSE_ENABLED=false
ADSENSE_PUBLISHER_ID=YOUR_REAL_CA_PUB_ID
ADSENSE_CMP_SCRIPT_URL=YOUR_CMP_INSTALLATION_SCRIPT_HTTPS_URL
ADSENSE_SLOT_FEED_INLINE=YOUR_SLOT_ID
ADSENSE_SLOT_FEED_FOOTER=YOUR_SLOT_ID
ADSENSE_SLOT_COMMUNITY_RAIL=YOUR_SLOT_ID
ADSENSE_SLOT_ARTICLE_FOOTER=YOUR_SLOT_ID
ADSENSE_SLOT_PUBLIC_NOTE_FOOTER=YOUR_SLOT_ID
```

The uppercase values above are documentation placeholders and must be replaced. No AdSense login credentials, tax data or API secrets belong in these fields.

6. Prepare and build:

```sh
python3 scripts/prepare_client_config.py
flutter build web --release
npx wrangler deploy
```

The preparation command allowlists public settings, validates the publisher ID, adds the `google-adsense-account` ownership meta tag, and writes the authorized seller entry to `web/ads.txt`. With no publisher ID it removes the meta tag and leaves a comments-only ads.txt, so a fake seller is never published. Configuration and the verification files must be regenerated together whenever the publisher ID changes. An enabled slot also needs a valid slot ID.

7. Verify the deployed `https://alphajournal.in/ads.txt` returns **text/plain**, not the SPA HTML, and contains your `pub-...` seller ID. Verify the HTML meta tag matches the same `ca-pub-...` ID. The files are public and do not load tracking just to prove ownership. Request site review in AdSense. Do not enable until Google reports the site ready.
8. Confirm the AdSense crawler can actually reach and understand the content to be monetized. Much of this app requires sign-in and renders with Flutter; a working browser route does not prove crawler access. Configure AdSense's supported crawler login for gated content if applicable, and inspect crawler errors. Do not disable authentication or database protections for crawlers. If Google cannot crawl or evaluate the content, keep that placement disabled and provide an appropriate public rendering before monetizing it.
9. Before enabling, update the publication-pack source policies that currently say AdSense is planned/inactive to describe the actual live deployment, regenerate the published library/artifacts, and verify the privacy, cookies, advertising, contact and consent links remain available without sign-in. Confirm the paid-plan advertising promise matches the purchase terms.
10. Set `ADSENSE_ENABLED=true`, rebuild and deploy after these steps. Leaving it false is the kill switch. Never click your own live ads to test them.

## Consent and lifecycle behavior

The browser adapter receives only eligibility booleans, expiry time, publisher ID and slot identifiers. It is not given account IDs, record titles, portfolio values, messages or search queries as targeting data. Google can still receive ordinary browser/page-context information when an authorized ad request is made.

No CMP/ad script is requested until a configured slot exists, the server has confirmed an active **free customer** account, the current route is eligible, and the user has saved current advertising permission. The adapter additionally waits for a successful TCF CMP event. Unknown applicability fails closed. Where GDPR applies, it requires a TCF string, storage purpose consent and consent for Google's vendor ID; Google evaluates its own additional TCF requirements. Personalisation is disabled unless both local choices and the relevant CMP purposes allow it. Outside GDPR applicability the CMP must report that explicitly; the app does not guess location.

Changing consent, expiry, loss of account access, logout, or leaving for a paid/private route cancels pending requests and removes the units. If a third-party SDK has already started, the browser reloads the current route once to unload it completely. Opening an already configured CMP dialog alone does not count as consent. Existing Cookie preferences remain available through Help and settings.

## Verification checklist

- Missing/invalid publisher or slot IDs: no AdSense script/request.
- Unknown, paid, suspended, admin or affiliate account: no placements.
- Advertising rejected, expired, saving, or storage failure: no optional SDK request.
- CMP absent/failed/undetermined/refused: no ad request.
- Public content at approved placements only; no Google scripts initialized by private routes.
- Consent withdrawal or plan change cancels pending requests and unloads third-party scripts.
- 320px, 390px, tablet and desktop layouts: readable labels, reserved space, no overlap.
- Private/empty/unmoderated/short content and third-party summaries: no ad slot.
- Ad blockers/network failures/unfilled inventory: content still works.
- No live ad click is part of QA; use the offline preview and automated tests.

## Official references checked for this implementation

- [Connect and verify an AdSense site](https://support.google.com/adsense/answer/12169212)
- [Authorized sellers / ads.txt](https://support.google.com/adsense/answer/12171612)
- [Ad placement policies](https://support.google.com/adsense/answer/1346295)
- [Responsive display behavior](https://support.google.com/adsense/answer/9183362)
- [Google certified-CMP requirements](https://support.google.com/adsense/answer/13554116)
- [Crawler login for protected content](https://support.google.com/adsense/answer/161351)

Publisher verification, account/site approval, CMP configuration, editorial policy review and actual live inventory remain account-side steps. This integration prepares the product; it cannot perform or guarantee Google's approval.
