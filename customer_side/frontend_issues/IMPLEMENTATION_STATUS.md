# Customer frontend implementation status

This report records verified frontend fixes separately from service dependencies and unverified audit claims. No production deployment or GitHub issue closure was performed.

## Latest frontend completion pass — October 22, 2026

The previous committed baseline is extended by the changes below. Validation now passes **415 tests**, static analysis, the release web build and `git diff --check`. The scripts themselves also pass Bash/Python syntax and association-input checks. This pass is recorded in a local commit; no deployment, push or GitHub issue closure is included.

- **#21 Authentication:** Account-mode debug builds now reject preview-role URL overrides. Preview identities require both debug mode and the explicit demo entrypoint. Login preserves validated internal `next` destinations, including record IDs and visibility context; external/unknown/recursive authentication targets are rejected.
- **#22 Community:** Hub selections notify the shell URL owner. Standalone desktop/tablet hub navigation now renders shared tabs. Feed subtabs restore from and write URL query state. Pull-to-refresh awaits the repository and reports failures while preserving existing content. The previously implemented publication/access safeguards remain in place.
- **#24 Notes:** Word counting now follows the preview debounce rather than rescanning on every keystroke. An immediate-save regression proves the complete latest pasted body and derived counts are saved before that display debounce fires. Existing canonical attachment and owner/public regressions continue to pass.
- **#25 Strategies:** Compact layouts show Write as the effective mode when a previously selected Split mode no longer fits. A real editor interaction check covers desktop-to-tablet resize, Read selection, opening More, publication consent and cancellation.
- **#27 Watchlists:** Shared ticker cards now expose removal from the aggregate watchlist view, with explicit confirmation and real repository writes. Failed symbol creation retains its selection; retry reuses the newly created watchlist. The picker reduces its list height when showing an error on short viewports. Account writes and alerts reject unconfigured/unauthenticated saves; alert writes require a confirmed row.
- **#28 AI:** Added authenticated SSE transport to the configured project's `ai-copilot` function, rendering real deltas, explicit completion, Stop, retry, provider errors, idle/overall deadlines and interrupted output. Failed prompts and partial answers are retained. Duplicate sends are rejected; thread changes, account changes and disposal cancel requests and reject late responses. Account changes clear prior conversation state. New thread IDs are UUIDs. Live responses do not inherit fabricated seed actions; normal-mode insight requests enter the actual chat. AI-created Community posts await persistence.
- **#30 Settings / #32 Affiliate:** Support submission has duplicate-send protection, preserves drafts on failure and clears only after the injected delivery callback completes. Its success message no longer promises an unsupported response deadline. Saved payout preferences no longer claim that a transfer will occur. Existing explicit unavailable payment/SMS/payout states are retained.
- **#31 Workspace:** The main scroll position is saved with calendar/filter state and restored when returning to the desk or closing an embedded editor. A regression verifies actual scroll restoration.
- **#52 Navigation:** Added shared route state for Community feed subtabs and AI workspace tabs/desktop panels; URL changes restore the selected views. Overlays preserve their source location. Custom-scheme development registration remains active. The new association generator validates real signing identifiers and produces public website association files; it does not invent a domain, Team ID or release certificate.

Use [development instructions](DEVELOPMENT.md) for the demo/account launchers, repeatable checks, streaming endpoint contract and HTTPS association generation. New evidence lives in `test/features/ai_assistant/ai_streaming_test.dart`, `test/core/navigation/feature_location_test.dart`, `test/features/customer_frontend/remaining_frontend_flows_test.dart` and `test/features/customer_frontend/note_support_workflow_test.dart`.

**Additional complete frontend scopes:** #24, #25, #27 and #31 now have the missing implementation and interaction evidence, alongside previously completed #23, #29 and #33. Other scopes have implemented client behavior but still need the release/service validation listed below. The GitHub open count is not used as an implementation-completion count.

**Actual remaining dependencies:** a deployed authenticated `ai-copilot` provider function; support/moderation/payment/SMS/audio/export/deletion services; real signing and hosting identifiers for verified HTTPS links; and native-device OAuth, keyboard/touch/gesture validation. Rich Community poll/edit/scheduling and restricted-reply server enforcement remain separate unfinished service contracts. Every transient dialog is not a refresh-restorable route. Cold parsing at very large portfolio sizes remains a measured performance limit. These limits prevent claiming that every original issue is completely resolved in production.

## Validation

- `flutter analyze`: no issues.
- `flutter test`: **415 tests passed** across the full suite. This includes 50 main-destination layout cases, 93 calculator/settings detail cases, 12 compact authentication cases, and button/system-back regressions for post → linked note → original post. Final account-data/AI/back regressions also pass (10 tests).
- `flutter build web --release`: succeeded (main application entrypoint).
- `git diff --check`: passed.
- Reproduce with `scripts/verify_customer_frontend.sh`; it saves analyzer, full test, and release-build logs in `validation/`.
- Current follow-up used scripted Flutter checks. Chrome access is now available: the signed-in issue list was checked and the explicit demo preview was inspected on desktop. The latest storage/access changes are covered by tests and compilation, not authenticated production-device interaction.
- Chrome live preview: desktop 1440 px workspace/notes; selecting a note changes its URL and refresh restores it; browser back returns to the desk. Mobile 390 px journal table preference shows readable cards and community has one dock; 320 px community/audio preview checked visually. Preview uses local demo repositories and does not establish production backend correctness.
- Debug preview encountered Flutter/DWDS reload and semantics-node errors after repeated hot restarts. These are recorded as a development-preview limitation, not proof of clean production console behavior.


## 2026-10-22 overflow, back-navigation and customer-data follow-up

The shell now stores the exact originating destination and record request for linked-record jumps. Opening a published note from an opened community post returns to that post using the note back button or mobile system back. The route-aware regression rebuilds the shell as location changes and asserts the originating post ID. Explicit sidebar navigation clears this link-return stack; changing roles clears it too.

Writing pages retain their own record back control on mobile; the shell suppresses its duplicate control. Community post selection updates the record URL, and closing the post clears the pending request to prevent it reopening on a repository refresh.

The scripted layout matrix covers the ten primary customer destinations at 320/390/768 px, 390 px with 150% text, and 740×320 landscape. Another 93 cases cover 22 calculator pages and nine customer settings sections at narrow, enlarged-text and landscape sizes. Fixes include shared section headers/pagination, calendar dimensions, notes collection controls, journal/strategy filter headers, strategy metrics, AI thread annotations, calculator quote/sync controls and headline tags, P&L actions, authentication headers/dividers and carousel scrolling.

`CustomerDataPolicy.allowDemo` defaults to false. Only the explicit preview entrypoint and test configuration enable samples. The customer repositories no longer initialize seeded community records, threads, watchlists, personal notes/trades/strategies or AI history/insights in normal mode. Workspace post-link sample fallbacks are disabled, as are fabricated account details, blocked users, affiliate earnings, payment cards and invoices. Missing/failed authentication no longer falls back to local mock sign-in. The AI chat shows service unavailability instead of generating canned account responses. Bundled market snapshots and calculator reference inputs remain labeled reference data.

These changes do not provision live AI, payment, SMS, export-worker or support services. Physical iOS/Android gestures, platform callbacks and authenticated production-service flows still require device/service validation.

## October 22 access and functionality follow-up

GitHub was checked through the existing Chrome session: **17 frontend issues remain open**, #21–35 and #51–52. The fixes below are local working-tree changes; GitHub issues have not been closed or represented as deployed.

- Record ownership now comes from the authenticated actor and saved owner, never a route flag. Notes, journal and strategy readers reject unavailable/private records, deny foreign editing and clear caches when the actor changes. Publishing notes and journals requires explicit confirmation, matching strategies.
- The Community picker loads actual owned records. Quick Create saves a real private record; refresh replaces stale options. Before publishing, the composer re-resolves ownership and source visibility. Private/deleted source attachments hide saved title/excerpt snapshots, including while a reader is already open. Quoted posts use the current original's public status.
- Post creation saves a private draft, writes children, then publishes last. Failed writes preserve the composer, and confirmed owner-filtered updates/deletes precede local success. Attachment publication is rolled back if post creation fails; rollback failures explicitly ask the user to review visibility. This is a compensating client workflow, not a server transaction.
- Source uploads now use the documented `<user_id>/<record_id>/<file>` storage prefix, verify ownership and propagate upload errors. Private buckets use ten-minute signed URLs, with shorter bounded caches scoped by actor and resolver. Existing deployed bucket/RLS policies still require live verification.
- Note/journal favorites persist on this device under actor-specific keys, instead of writing nonexistent note/journal columns. Strategy favorites use confirmed owned writes. Note engagements rely on database count triggers rather than overwriting another author's aggregate counts.
- Removed fabricated broker connections, sync latency, live market telemetry, default poll demographics and inferred post analytics. Unconnected moderation delivery cannot report successful submission. Directory instruments with no exported quote still open research; missing quotes display as unavailable. Market likes are scoped by actor.
- Parsed Markdown links are cached with weak keys on immutable records. The debug scale harness measured a repeated graph/index rebuild at approximately **4.6 ms for 5,000 records**, versus approximately **176 ms** for cold parsing. Edits invalidate the cache. Cold parsing and large-document rendering remain scaling concerns; these measurements are not a physical-device performance guarantee. The 310,000-character stats/excerpt check measured approximately 44 ms.

Additional regressions cover forged owner URLs, revoked visible attachments, zero-row denied writes, persisted Quick Create sources, stale picker removal, draft publication ordering and private-feed filtering. See [privacy flows](/Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/test/features/customer_frontend/record_privacy_flow_test.dart) and [scale evidence](validation/scale-profile.log).

Remaining server-dependent scope: AI provider/streaming, audio transport, payments, SMS, support/moderation delivery, export/deletion workers, atomic rich post edits, poll aggregate/voting lifecycle, restricted replies and scheduling enforcement. The post writer rejects unsupported scheduling/reply modes instead of dropping those selections. Quotes retain an original-post permalink in persisted text; rich quote round trips still need a schema contract. Public journals additionally depend on the profile-wide visibility rule. No production SQL, secrets or external service provisioning was changed.

## Commit readiness review

Checked the recorded GitHub issue work items against the final code and regression evidence on October 22, 2026. Complete means the scoped frontend work is implemented and locally verified; it does not mean deployed or that the GitHub issue has been closed.

| Complete frontend issue | Evidence |
|---|---|
| #23 — Trade journal: compact trade views, owner link visibility, calculator handoff | Compact card fallback, owner/public access separation and reviewed calculator drafts; journal, link privacy, calculator handoff and viewport regressions pass. |
| #29 — Calculators: invalid arithmetic, tax regimes, journal drafts | Finite-result guards, explicit historical/current equity-tax periods and journal draft transfer; calculator logic and detail-layout regressions pass. |
| #33 — Public site: narrow pricing typography, footer destinations, security copy | Shared responsive pricing, verified project destination/unconfigured social removal and unsupported claims removed; pricing tests include 320/360 px at 150% text and 1024 px. |

The table above records the earlier commit baseline. The latest pass adds completion for #24 (notes), #25 (strategies), #27 (watchlists) and #31 (workspace), supported by the interaction checks and full validation recorded above.

Commit status tags (frontend scope only):

- `[completed]`: #23, #24, #25, #27, #29, #31, #33.
- `[partially-completed]`: #21, #22, #26, #28, #30, #32, #34, #35, #51, #52.

The partial scopes still need service integration, cold-path performance work, native/device validation or extended routing as detailed in the issue mapping. These tags describe implementation status; they do not close GitHub issues.

The commit-readiness baseline comprised the full 390-test suite plus three new pricing cases. The latest pass above supersedes that snapshot with a complete 415-test run, clean analyzer and successful release build.

## Issue mapping

| GitHub issue | Status | Result / remaining work |
|---|---|---|
| [#21](https://github.com/NK2552003/TradeX/issues/21) auth | Implemented; live identity validation pending | Google OAuth launch/error states; verified recovery token/password update and duplicate-submit protection; production debug role switch hidden; unsupported encryption copy removed. Real OAuth, OTP delivery and native callback round trips need configured services/devices. |
| [#22](https://github.com/NK2552003/TradeX/issues/22) community | Implemented frontend safeguards; service work pending | Real picker/Quick Create, confirmed post saves/deletes, revoked-source protection, quote composer and real refresh; unavailable report/mute actions disabled; private attachment publication requires confirmation; fabricated advisor number removed; truthful audio-preview labels; narrow comment/author/audio controls wrap. Existing embedded single dock retained. |
| [#23](https://github.com/NK2552003/TradeX/issues/23) journal | Complete frontend scope | Compact table preference renders readable cards; owner/public link permissions separated; calculator output opens an unsaved draft for review. |
| [#24](https://github.com/NK2552003/TradeX/issues/24) notes | Complete frontend scope; device scaling limit documented | Canonical staged-attachment boundary applies to preview and PDF including symlink denial; arbitrary local image paths rejected; keyboard inset applied once; safe HTML anchors launch allowed URL schemes; owner linked-record visibility preserved. Existing extraction debounce retained; 310,000-character stats/excerpt profile recorded, without a physical-device performance claim. |
| [#25](https://github.com/NK2552003/TradeX/issues/25) strategies | Complete frontend scope | Shared dropdown pointer/keyboard behavior fixed; publication requires confirmation; owner links preserved; metric ribbon wraps in narrow cards. Existing local-width split fallback retained. |
| [#26](https://github.com/NK2552003/TradeX/issues/26) market data | Implemented; physical gesture validation pending | Bundled-data provenance and non-advisory caption replace invented delay; chart gains horizontal edge spacing. Existing responsive mover/research layouts covered by suite. Physical iOS/Android edge-back gestures remain unverified. |
| [#27](https://github.com/NK2552003/TradeX/issues/27) watchlists | Complete frontend scope | Searchable catalogue picker supports first-watchlist creation and add/remove; saving/error/retry states; ticker navigation; quotes use bundled market data and unavailable values never masquerade as prices. Configured backend writes require authenticated ownership. |
| [#28](https://github.com/NK2552003/TradeX/issues/28) ai assistant | Client streaming complete; deployed provider pending | Authenticated SSE, cancellation, retry, interruption, timeout, account isolation and completion are implemented and tested. A deployed authenticated provider function remains required. |
| [#29](https://github.com/NK2552003/TradeX/issues/29) calculators | Complete frontend scope | Finite input/zero-risk guards; explicitly selected historical/current Indian equity capital-gains periods; position/risk outputs transfer into reviewed journal drafts. |
| [#30](https://github.com/NK2552003/TradeX/issues/30) settings | Implemented with external services pending | Email OTP verification, real identity linking and current-password reauthentication; truthful deletion request and sign-out; invoice PDF export; actual ready archive URL validation; unavailable billing/support actions disabled; referral clipboard fixed. Export worker, payments, ticket delivery and permanent deletion remain service work. |
| [#31](https://github.com/NK2552003/TradeX/issues/31) workspace | Complete frontend scope | Scroll, search and calendar/filter snapshot survive leaving the desk; shell history avoids cycles. Carousel controls were already outside cards. Linked record returns preserve the source post. Main desk scroll is restored; independent nested carousel offsets remain local to each carousel. |
| [#32](https://github.com/NK2552003/TradeX/issues/32) affiliate program | UI corrected; SMS/payout services pending | Unconfigured SMS verification disabled with explicit copy; referral link copies on both layouts. Payout destination already shows an unavailable/placeholder surface. Verification and settlement services still required. |
| [#33](https://github.com/NK2552003/TradeX/issues/33) public site | Complete frontend scope | Responsive price text scales down; unconfigured social actions removed in favor of verified project GitHub link; unsupported encryption claims removed. |
| [#34](https://github.com/NK2552003/TradeX/issues/34) linking | Implemented cache; cold-path scaling remains | Ticker universe loads from asset catalogue rather than stale demo-only symbols; repository/injected test seams preserved. Weak-record parsing cache and reproducible 100/1,000/5,000-record debug profile; cold parsing remains above a frame budget at 5,000 records. |
| [#35](https://github.com/NK2552003/TradeX/issues/35) messages | Implemented; physical keyboard validation pending | Unsupported E2EE claim removed; authenticated empty fetch clears seeded conversations; existing SafeArea retained. Native gesture navigation and real messaging transport not live-tested. |
| [#51](https://github.com/NK2552003/TradeX/issues/51) layout and responsive | Implemented for reproduced defects; device matrix incomplete | Shared menu viewport/keyboard bounds; editor inset ownership; compact journal cards; comments/audio controls and strategy metrics wrap; pricing scales. Widget widths cover 320/390/768/1024/1440 where relevant; native large-text/landscape/edge gestures are not exhaustively validated. |
| [#52](https://github.com/NK2552003/TradeX/issues/52) navigation and routes | Implemented core routes; extended routing remains | go_router covers auth, shell and record URLs; Community/AI tab selections and internal login returns now synchronize; selected saved notes/trades/strategies update URLs; refresh restores records; browser back/forward updates shell; stale callbacks/history loops corrected; native tradex scheme registered. Every feature subtab/dialog is not URL-addressable; HTTPS association files need an actual deployment domain, and native intent round trips remain unverified. |

## Evidence

Follow-up logs: [primary page layout matrix](validation/customer-page-layouts.log), [calculator/settings matrix](validation/customer-detail-layouts.log), [origin-return regression](validation/linked-post-back.log), [customer data/AI/back checks](validation/customer-data-back.log).


- [Analyzer output](validation/analyze.log)
- [Full Flutter test run](validation/flutter-test.log)
- [Audio preview regression tests](validation/audio-preview-regressions.log)
- [Release build output](validation/web-release-build.log)
- [Desktop workspace](validation/desktop-workspace-1440.png)
- [Desktop refreshed note URL](validation/desktop-note-deep-link-1440.png)
- [Mobile journal](validation/mobile-journal-390.png)
- [Mobile community at 320 px](validation/mobile-community-320.png)
- [Mobile audio preview at 320 px](validation/mobile-audio-preview-320.png)

## References used for integration and tax assumptions

- [Supabase OAuth](https://supabase.com/docs/reference/dart/auth-signinwithoauth), [OTP verification](https://supabase.com/docs/reference/dart/auth-verifyotp), [user updates](https://supabase.com/docs/reference/dart/auth-updateuser), [identity linking](https://supabase.com/docs/guides/auth/auth-identity-linking).
- [go_router configuration](https://pub.dev/documentation/go_router/latest/topics/Configuration-topic.html).
- [Income Tax Department: sale of shares](https://www.incometaxindia.gov.in/en/sale-of-shares) and [new capital-gains regime FAQ](https://www.incometaxindia.gov.in/documents/20117/14614766/FAQs%2B-New-Capital-Gains-Taxation-regime.pdf/ad59d362-7bce-f0aa-e483-ce0f61ac13d6?t=1767816817352).

Existing unrelated auth-repository, message-test and skills/catalogue changes were preserved. Backend migrations, production secrets, billing charges, permanent account deletion and external messages were not part of this frontend implementation.

Storage API reference: [Supabase signed URLs](https://supabase.com/docs/reference/dart/v1/storage-from-createsignedurl).
