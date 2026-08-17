# Screens — Mobile (iOS / Android)
## Full Screen + Sub-Screen Inventory, Components, and States

This is the **primary/baseline screen spec** — [SCREENS_TABLET.md](./SCREENS_TABLET.md) and [SCREENS_DESKTOP.md](./SCREENS_DESKTOP.md) only document how each screen's layout *adapts* on larger breakpoints; content/fields are defined once, here. Per-screen mermaid state/flow diagrams: [UI_FLOW_DIAGRAMS.md](./UI_FLOW_DIAGRAMS.md). Visual tokens: [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md). Navigation/deep-linking: [DYNAMIC_LINKING.md](./DYNAMIC_LINKING.md). Product context: [PRD.md](./PRD.md).

**Mobile navigation pattern:** bottom tab bar (7 tabs — see note in SCREENS_AND_FLOWS.md § 0 about collapsing to a "More" tab), full-screen modals for create/edit flows, bottom sheets for quick actions, native back gesture/button for stack navigation.

Tier gating shorthand: **F** = Free, **P** = Premium, **E** = Enterprise (post-MVP).

**Tagging convention (this revision):** every screen that fetches data on mount now explicitly tags **Loading** and **Error** (previously only Empty state was tagged consistently — Loading/Error existed only as a cross-cutting convention with no per-screen confirmation, which was a real gap). Every screen with a save/delete/action-complete moment now explicitly tags **Toast**. Pure static forms (Sign Up, Log In, most create/edit forms) don't fetch on mount and are correctly left untagged for Loading/Error — that's not an oversight, they have nothing to load.

---

## Cross-cutting sub-screens (apply across all modules)
These recur throughout the app and are specced once here rather than repeated per module:

| Sub-screen / state | Contains |
|---|---|
| **Loading state** | Skeleton placeholders matching the target screen's card/list shape (not a bare spinner, except on first cold launch) |
| **Empty state** | Icon, one-line message, primary CTA (e.g. "No journal entries yet" → "Create your first entry") |
| **Error state** | Icon, one-line error message, "Retry" button |
| **Confirmation dialog** | Title, short body copy, Cancel + destructive-styled confirm button (delete entry, delete strategy, remove team member, etc.) |
| **Image viewer / lightbox** | Full-screen image (screenshots, post images), pinch-zoom, swipe-to-dismiss, share/download icon |
| **Bottom sheet (generic pattern)** | Drag handle, title, content, primary action pinned to bottom — used for: Add Ticker quick-add, content-type picker, sort/filter options, share sheet |
| **Toast / snackbar** | Bottom-anchored, auto-dismiss, used for: save confirmations, undo actions (e.g. "Entry deleted — Undo") |
| **Upsell / paywall interstitial** | Triggered mid-flow when a Free-tier user hits a locked action; shows the specific feature they hit, "Upgrade" CTA, "Not now" dismiss |

---

## 1. Auth & Profile

### Splash / Onboarding — All
- App logo/wordmark, centered
- Value-prop carousel (swipeable, 5 slides — one per pillar), page indicator dots
- Primary button: "Get Started" (pinned bottom)
- Secondary text link: "Log In"

### Sign Up — All
- Back button (top-left)
- Email field, Password field (+ show/hide toggle, strength meter below)
- Handle field (+ live availability check, inline checkmark/error)
- Divider "or"
- "Continue with Google" button (full-width, Google icon)
- "Continue with Apple" button (full-width, Apple icon)
- ToS/Privacy checkbox + inline links
- Primary button: "Sign Up" (disabled until valid)
- Bottom text link: "Already have an account? Log In"
- Error state (see cross-cutting): inline, for signup failures (email already registered, network failure) — not a full-screen replacement, shown above the submit button so the filled fields aren't lost

### Log In — All
- Back button
- Email field, Password field
- OAuth buttons (as above)
- "Forgot password?" link (right-aligned under password field)
- Primary button: "Log In"
- Bottom text link: "Sign Up"
- Error state (see cross-cutting): inline, for invalid credentials or network failure

### Forgot Password — All
- Back button, email field, "Send reset link" button
- Sub-screen: confirmation state (replaces form) — checkmark icon, "Check your email" message, "Resend" link (rate-limited)
- Error state (see cross-cutting): inline, for network failure on submit

### Own Profile — All
- Top bar: Settings icon (top-right)
- Loading state (see cross-cutting): skeleton for avatar/handle/stats on first open
- Avatar (tap → image picker bottom sheet), edit pencil overlay
- Handle (tap-to-edit inline)
- Bio (tap-to-edit inline, multi-line)
- Experience level chip + Trading style chip (tap → picker bottom sheet)
- Tier badge (tap → Manage Subscription if Premium/Enterprise, or Paywall if Free)
- Stat row: Followers count | Following count (tap either → Followers/Following List)
- Public statistics card (win rate, total P/L) — only rendered if user has sharing enabled
- "Public Journals" toggle row
- Segmented control: Posts / Strategy Notes / Journal (public)
- Content grid/list below segmented control, per selected tab
- FAB or top-right "+": context-sensitive (new post if on Posts tab, etc.)
- Error state (see cross-cutting): if the initial profile fetch fails
- Toast (see cross-cutting): confirms inline edits (handle, bio, chips, toggle) save successfully; rolls back with an error toast on failure

### Public Profile (other user) — All
- Loading state (see cross-cutting): skeleton for avatar/handle/stats
- Back button, overflow menu (Report/Block)
- Avatar, handle, bio, experience level chip, trading style chip
- Stat row: Followers | Following
- Public statistics card (if shared)
- Follow/Unfollow button (primary, full-width)
- Message button (secondary, next to Follow/Unfollow) — tier-gated on the *viewer's* own subscription (Direct Messages, § 7): Premium/Enterprise viewers go straight to Conversation Detail (existing or new); Free-tier viewers see the upsell interstitial instead. Not shown at all if viewing your own profile, obviously.
- Segmented control: Posts / Strategy Notes / Journal (public)
- Content grid/list below
- Error state (see cross-cutting): if the profile doesn't exist or fetch fails (same deliberately-vague "not available" message as any private-content-not-found case, per ERROR_HANDLING.md backend doc § 2)
- Toast (see cross-cutting): confirms Follow/Unfollow and Report/Block actions

### Settings — All
- Section: Notifications → row linking to Notification Preferences
- Section: Account → Change Email row, Change Password row
- Section: Privacy → "Public Journals" toggle
- Section: Subscription → row showing current tier, links to Manage Subscription or Paywall
- Section: Enterprise (only visible if org member) → "Organization" row → Org Dashboard
- "Log Out" button (destructive-adjacent styling, not full red)
- "Delete Account" row (bottom, red text, opens confirmation dialog)
- Toast (see cross-cutting): confirms email/password change and toggle saves; error toast on failure (e.g. wrong current password)

---

## 2. Trading Journal

### Journal List — F (limited) / P+ (unlimited)
- Top bar: title "Journal", search icon (expands to search bar), filter icon
- Filter bottom sheet (sub-screen): ticker input, date range picker, tag multi-select, strategy multi-select, outcome multi-select, "Apply"/"Clear" buttons
- Loading state (see cross-cutting): skeleton entry cards on first open
- Entry cards (vertical list): ticker + date (top row), outcome badge + P/L (right-aligned), notes snippet (2-line truncate)
- Pull-to-refresh
- Empty state (see cross-cutting)
- Error state (see cross-cutting): if the entry list fails to load
- FAB: "+" → Journal Entry Create
- Free-tier banner (dismissible, shown near/at entry limit): "3 entries left this month — Upgrade for unlimited"

### Journal Entry Detail — F/P/E
- Loading state (see cross-cutting): skeleton for the full field layout on open
- Top bar: back button, overflow menu (Edit / Delete / Make Public toggle / Link to another entry)
- Ticker header (large, tappable → Ticker Detail)
- Outcome badge (large, tappable → outcome override bottom sheet)
- Trade fields grid (2-column): Entry / Exit / Stop Loss / Target / Size / Side / P/L — mono numerals
- Screenshot carousel (horizontal scroll, tap → Image Viewer)
- Notes section (expandable if long)
- Psychology section
- Mistakes Made section
- Lessons Learned section
- Linked strategy chip (tap → Strategy Detail)
- Tag chips row
- Bottom action bar (Premium): "AI Trade Review" button
- Error state (see cross-cutting): entry not found or fetch failed
- Toast (see cross-cutting): "Entry deleted — Undo" on delete; confirms outcome override and Make Public toggle saves

### Journal Entry Create/Edit — F/P/E
- Top bar: Cancel (left), "Save" (right, disabled until required fields filled)
- Ticker autocomplete field
- "Attach Screenshot" button/card → camera/gallery bottom sheet → upload progress inline → parsed-fields banner ("Filled from screenshot — review below")
- Trade fields (editable, pre-filled if parsed): Entry / Exit / Stop Loss / Target / Size / Side (segmented long/short)
- P/L (auto-computed, shown read-only with a small "override" pencil icon)
- Notes text area (expands with content)
- Psychology / Mistakes Made / Lessons Learned text areas (collapsed by default, "Add psychology notes" style expand-on-tap affordance to avoid overwhelming the form)
- Tags input (chip entry, autocomplete against existing tags)
- Strategy picker row → bottom sheet: search existing / "Create New Strategy" shortcut
- Error state (see cross-cutting): inline, for screenshot-parsing failure (falls back to manual entry, doesn't block the form) and for save failure
- Toast (see cross-cutting): "Entry saved" on successful create/edit

**Sub-screen — Outcome override bottom sheet:** current outcome shown, three large tap targets (Win / Loss / Breakeven), "Reset to auto" link.

---

## 3. Strategy Notes & Analyzer

### Strategy List — F: locked/upsell · P/E: full
- Top bar: title "Strategies", tabs: List / Analyzer / Graph
- Category filter chip row (horizontal scroll)
- Loading state (see cross-cutting): skeleton strategy cards on first open (Premium/Enterprise only — Free sees the lock state instead, below)
- Strategy cards: title, category chip, visibility icon, favorite star (tap to toggle), win-rate mini-badge if linked entries exist
- FAB: "+" → Strategy Editor (new)
- Free-tier: full-screen locked state with illustration + "Unlock Strategy Notes" CTA
- Premium/Enterprise, no strategies yet: standard empty state (see cross-cutting) — "No strategies yet" → tap CTA opens Strategy Editor
- Error state (see cross-cutting): if the strategy list fails to load

### Strategy Detail — P/E
- Loading state (see cross-cutting): skeleton for title/body/metadata on open
- Top bar: back, overflow (Edit / Delete / Version History)
- Title (large)
- Category chip, visibility toggle (segmented: Private/Public), favorite star
- Rendered rich-text body (scrollable), embedded images inline at full card width
- AI Summary card (Premium) — italic/tinted background, "Regenerate" text button
- "Used in N journal entries" row → tap opens Analyzer filtered to this strategy
- Bottom action bar: "Edit" button
- Error state (see cross-cutting): strategy not found (private and not owner, or deleted) or fetch failed
- Toast (see cross-cutting): "Strategy deleted" on delete; confirms visibility toggle and favorite-star changes; confirms AI summary regeneration or shows an error toast on failure

### Strategy Editor — P/E
- Top bar: Cancel, "Save"
- Title field
- Formatting toolbar (bottom-anchored above keyboard, iOS/Android standard pattern): Bold/Italic, Heading, Bullet list, Image insert, Chart/embed insert
- Rich text body (full-screen editable area)
- Bottom sheet (on "settings" icon tap): Category picker, Visibility toggle
- Autosave indicator (small text, top-right: "Saved" / "Saving…")
- Error state (see cross-cutting): inline, if a save (autosave or manual) fails — autosave indicator switches to "Not saved — Retry" rather than silently failing
- Toast (see cross-cutting): confirms an explicit "Save" tap beyond the passive autosave indicator, e.g. when publishing a new version

### Version History — P/E
- Loading state (see cross-cutting): skeleton list on open
- Top bar: back, title "Version History"
- List: version number + relative timestamp
- Tap row → read-only preview screen (sub-screen) with "Restore This Version" button pinned bottom
- Error state (see cross-cutting): if version history fails to load
- Toast (see cross-cutting): "Restored version N" after a successful restore

### Strategy Analyzer — P/E
- Loading state (see cross-cutting): skeleton rollup cards on open
- Top bar tab context (from Strategy List tabs)
- Sort control (dropdown/bottom sheet: Win Rate / P&L / Entry Count)
- Rollup cards: strategy name, win rate %, avg P/L, entry count, mini outcome-distribution bar
- Tap card → filtered Journal List (pre-applied strategy filter)
- Empty state (see cross-cutting): no strategies with linked entries yet — "Link a strategy to your journal entries to see performance here"
- Error state (see cross-cutting): if the rollup query fails

### Graph View — P/E
- Loading state (see cross-cutting): centered spinner while the graph data (entries, strategies, links) is fetched — a skeleton canvas isn't meaningful for a force-directed layout the way it is for a list
- Top bar tab context, "Link Entries" toggle button (top-right)
- Full-screen canvas: pinch-zoom, pan, tap node → relevant detail screen
- Legend (collapsible bottom sheet): node type key (entry/strategy/ticker), edge type key
- When "Link Entries" mode active: tap-to-select two nodes → confirm bottom sheet → creates edge
- Error state (see cross-cutting): if the graph data fails to load
- Toast (see cross-cutting): confirms a new entry-to-entry link was created

---

## 4. Watchlists

### Watchlist List — F: 1 · P/E: unlimited
- Loading state (see cross-cutting): skeleton watchlist cards on open
- Top bar: title "Watchlists"
- Favorites shortlist (horizontal scroll row, top)
- Watchlist cards (name, ticker count)
- FAB: "+" → Create Watchlist bottom sheet (name field only, single-purpose)
- No watchlists yet: standard empty state (see cross-cutting) — "No watchlists yet" → tap CTA opens Create Watchlist
- Error state (see cross-cutting): if the watchlist list fails to load
- Toast (see cross-cutting): confirms a new watchlist was created

### Watchlist Detail — F: no alerts · P/E: full
- Loading state (see cross-cutting): skeleton ticker rows on open
- Top bar: back, watchlist name (tap to rename), overflow (categories manage / delete watchlist)
- Category filter chip row
- Ticker rows: symbol, last price, day change (colored), notes icon if present, favorite star, swipe-left reveals Remove
- "+" row/button at bottom of list → Add Ticker
- Empty state (see cross-cutting): watchlist created but no tickers added yet — "No tickers yet" → tap CTA opens Add Ticker
- Error state (see cross-cutting): if the ticker list or live prices fail to load
- Toast (see cross-cutting): "Ticker removed — Undo" on swipe-remove; confirms rename

### Add Ticker — F/P/E (bottom sheet, not full screen)
- Ticker search field with live results
- Loading state (see cross-cutting): inline spinner in the results list while a search is in flight
- On select: category dropdown, optional note field, "Set price alert" toggle
- "Add" button pinned bottom
- Error state (see cross-cutting): inline, if the ticker search fails
- Toast (see cross-cutting): confirms the ticker was added, shown on the Watchlist Detail screen after the sheet closes

### Price Alert Setup — P/E (bottom sheet)
- Above/Below segmented toggle
- Threshold price input (numeric keypad)
- Live preview text: "Alert when AAPL crosses $230.00"
- "Save Alert" button
- Toast (see cross-cutting): confirms the alert was saved, shown after the sheet closes

---

## 5. Portfolio Dashboard

### Portfolio Dashboard — F: headline only · P/E: full
- Loading state (see cross-cutting): skeleton stat cards + chart placeholders on open
- Top bar: title "Portfolio", time-range segmented control (Weekly/Monthly), overflow (export — future)
- Headline stat cards (2×2 grid): Total P/L, Win Rate, Avg RR, Max Drawdown
- Equity Curve chart (full-width, scrollable/zoomable horizontally)
- Monthly Growth chart (bar chart, full-width)
- Win/Loss Distribution chart (donut or stacked bar)
- Best Trade card / Worst Trade card (side-by-side, tap → Journal Entry Detail)
- "Strategy Performance" section header + "See all" link (Premium; Free shows lock icon + upsell)
- Empty state (see cross-cutting): fewer than 5 journal entries with `pnl` set — per DESIGN_SYSTEM.md § 13's muted-placeholder-chart treatment, not the generic icon+CTA empty state, since the screen itself is still meaningful with partial data
- Error state (see cross-cutting): if `portfolio_stats` or the entry list fails to load

### Strategy Performance Breakdown — P/E
- Loading state (see cross-cutting): skeleton rollup cards on open
- Top bar: back button, title "Strategy Performance," overflow menu (sort options duplicated here for one-tap access)
- Summary strip (top, above the list): "N strategies with linked entries" count + portfolio-wide win rate for context, so per-strategy numbers below have a baseline to compare against
- Sort control (segmented or dropdown): Win Rate / Total P&L / Entry Count / Most Recent Activity — persists as the user's preference across visits (not reset each time)
- Time-range filter chip (optional, mirrors Portfolio Dashboard's Weekly/Monthly toggle — filters which linked journal entries count toward each strategy's stats)
- Rollup cards (reused `THStrategyCard`-style component from Strategy Analyzer, one per strategy with ≥1 linked entry):
  - Strategy title + category chip
  - Win rate (large, mono numerals) with a small outcome-distribution bar (win/loss/breakeven segments, colored per DESIGN_SYSTEM.md § 2)
  - Avg P/L (mono, signed and colored per outcome-win/loss tokens)
  - Entry count
  - Mini sparkline of that strategy's cumulative P/L trend (optional but valuable — helps distinguish "consistently solid" from "one big win carrying the average")
  - Tap target: whole card → Strategy Analyzer, filtered to this strategy
- Empty state (see cross-cutting): shown if the user has strategies but none have any linked journal entries yet — message: "Link a strategy to your journal entries to see performance here" → CTA to Journal List
- Error state (see cross-cutting): if the breakdown query fails
- Pull-to-refresh

---

## 6. Community

### Community Feed — F: limited · P/E: unlimited
- Loading state (see cross-cutting): skeleton post cards on first open
- Top bar: title "Community", saved-posts icon (top-right)
- Content-type filter chip row (horizontal scroll)
- Post cards: avatar + handle (tap → Public Profile), content-type badge, timestamp, text (truncated with "more"), image (if present, tap → Image Viewer), action row (like/comment/save counts + icons)
- Pull-to-refresh
- FAB: "+" → Create Post
- Free-tier daily-limit banner near/at cap
- No posts for the selected content-type filter: standard empty state (see cross-cutting) — "No posts in this category yet" (no CTA needed; the fix is switching filters, not creating content)
- Error state (see cross-cutting): if the feed fails to load
- Toast (see cross-cutting): confirms like/save actions with a brief inline animation rather than a toast in most cases, but a toast is used specifically for "Post reported" / "User blocked" confirmations from the overflow menu

### Post Detail — F/P/E
- Loading state (see cross-cutting): skeleton post + comment thread on open
- Top bar: back, overflow (Report/Block/Mute)
- Full post (same card, untruncated, tappable image)
- Action row: like (with count), save (with count)
- Comment thread (list), each comment: avatar, handle, text, timestamp
- Comment input bar (pinned bottom, above keyboard)
- Error state (see cross-cutting): post not found or fetch failed
- Toast (see cross-cutting): confirms comment posted, and Report/Block/Mute actions

### Create Post — F/P/E
- Top bar: Cancel, "Post" (disabled until content type + text present)
- Content-type picker (horizontal chip row, single-select, required)
- Text area
- Ticker tag field (optional, autocomplete)
- "Add Image" button → camera/gallery bottom sheet, thumbnail preview with remove "×"
- Error state (see cross-cutting): inline, if the post fails to publish (stays on the form, content preserved)
- Toast (see cross-cutting): "Posted" on success, shown after returning to Community Feed

### Saved Posts — F/P/E
- Loading state (see cross-cutting): skeleton post cards on open
- Top bar: back, title "Saved"
- Same card list as feed, swipe-to-unsave
- Empty state (see cross-cutting)
- Error state (see cross-cutting): if the saved list fails to load
- Toast (see cross-cutting): "Removed from Saved — Undo" on swipe-unsave

### Followers / Following List — F/P/E
- Loading state (see cross-cutting): skeleton user rows on open
- Top bar: back, segmented control (Followers/Following)
- Search field
- User rows: avatar, handle, follow/unfollow button
- No followers/following yet: standard empty state (see cross-cutting) — "No followers yet" / "Not following anyone yet" → CTA to Community Feed on the Following tab (discover people to follow), no CTA on the Followers tab (nothing to prompt)
- Error state (see cross-cutting): if the list fails to load

---

## 7. Direct Messages — P/E only (Free: locked/upsell everywhere in this module)

### Direct Messages List — P/E
- Loading state (see cross-cutting): skeleton conversation rows on open
- Top bar: title "Messages," new-message icon (top-right)
- Conversation rows, sorted by most recent activity (`conversations.last_message_at`): counterpart's avatar + handle, last message preview (truncated, one line), relative timestamp, unread indicator (dot or bold styling) if the latest message's `read_at` is null and it wasn't sent by the current user
- Swipe-left on a row → Mute / Delete conversation (delete removes it from *this user's* list view only — the thread and messages remain for the other participant; this is a client-side "hide," not a data deletion, since deleting someone else's readable history unilaterally isn't appropriate)
- Pull-to-refresh
- No conversations yet: standard empty state (see cross-cutting) — "No messages yet" → CTA opens New Message
- Free tier: full-screen locked state (same pattern as Strategy List's Free lock) with illustration + "Unlock Direct Messages" CTA — there's no partial/read-only view for Free, since a Free user by definition can't have sent or received anything in-app yet
- Error state (see cross-cutting): if the conversation list fails to load
- Toast (see cross-cutting): "Conversation hidden — Undo" on swipe-delete

### Conversation Detail (chat thread) — P/E
- Loading state (see cross-cutting): skeleton message bubbles on open, before the Realtime subscription establishes
- Top bar: back, counterpart's avatar + handle (tap → their Public Profile), overflow menu (Mute / Block / Report)
- Message list (reverse-chronological scroll, newest at bottom, standard chat layout): message bubbles left-aligned for the counterpart, right-aligned for the current user, timestamp shown on long-press or grouped by time-gap, read receipt indicator on the current user's own sent messages (matches `read_at` state)
- Real-time updates: new messages append live via the Supabase Realtime subscription (API_REFERENCE.md § 1) without a manual refresh
- Message input bar (pinned bottom, above keyboard): text field, send button (disabled when empty or when the current user's tier no longer permits sending — see tier-downgrade note below)
- **Tier-downgrade state:** if the current user's subscription has lapsed since the conversation started, the input bar is replaced with a compact upsell strip ("Resubscribe to keep messaging") rather than a full-screen block — the message history above stays fully visible and scrollable
- **Blocked state:** if either party has blocked the other, the input bar is replaced with a neutral, non-accusatory message ("You can't send messages in this conversation") — deliberately not stating which direction the block went, to avoid escalating a conflict
- Empty state (brand new conversation, no messages yet): centered prompt — "Say hello to [handle]" — rather than the generic cross-cutting empty state, since this is the start of a thread, not an error/absence
- Error state (see cross-cutting): if the conversation/message history fails to load, or if the Realtime subscription drops (shows a subtle "Reconnecting…" indicator rather than a full-screen error, since history is still visible and usable)
- Toast (see cross-cutting): inline failed-to-send indicator on the specific message bubble (with a Retry tap target) rather than a screen-level toast, since a chat's failure state needs to stay attached to the specific message

### New Message — P/E
- Top bar: Cancel (left), title "New Message"
- Search field: search by handle, results show avatar + handle + (if followed) a "Follows you" / "Following" indicator
- Loading state (see cross-cutting): inline spinner in the results list while a search is in flight
- Tap a result → if a conversation with that person already exists, opens the existing Conversation Detail directly (no duplicate thread created, matches the `unique (user_a_id, user_b_id)` constraint in the schema); otherwise opens a fresh Conversation Detail in its empty state, ready for the first message
- Free tier: this screen isn't reachable at all — the entry points that would open it (the "+" icon on Direct Messages List, and any "Message" button on a Public Profile) show the upsell interstitial instead of navigating here
- Error state (see cross-cutting): inline, if the handle search fails

---

## 8. AI Trading Assistant

### Ticker Search / Detail — F: basic · P/E: full
- Top bar: search field (persistent)
- Loading state (see cross-cutting): skeleton chart + indicator placeholders on open
- Price chart (candlestick, timeframe segmented control)
- Indicator toggles (RSI/MACD/SMA — chip row, tap to overlay on chart)
- News & Sentiment card (Premium; collapsed summary, "Read more" expand)
- "Ask AI about this ticker" button (Premium) — pinned above bottom nav
- Free tier: chart + indicators visible, News/Sentiment and Ask AI show lock state
- Error state (see cross-cutting): if price/indicator data fails to load (per INTEGRATIONS.md § 2, no cached-price fallback exists yet — this is a real error state, not stale data shown silently)

### AI Trading Assistant (chat) — P/E
- Top bar: back, scope selector (dropdown: this ticker / this watchlist / my portfolio)
- Chat thread (message bubbles, AI messages include disclaimer footnote inline)
- Quick-action chip row (above input): "Risk/Reward", "Watchlist Insights", "Ask something else"
- Message input bar (pinned bottom)
- Loading state (see cross-cutting): typing-indicator-style animation in place of the next AI bubble while a response streams in
- Error state (see cross-cutting): inline failed-to-respond indicator on the specific exchange (with a Retry tap target), same pattern as Conversation Detail's failed-send state

### Trade Review results — P/E (bottom sheet or full screen from Journal Entry Detail)
- Loading state (see cross-cutting): skeleton/spinner while the AI call is in flight
- Entry summary header (ticker, outcome, P/L)
- AI commentary block
- Disclaimer footnote
- "Re-run" / "Dismiss" buttons
- Error state (see cross-cutting): if the AI call fails — "Re-run" doubles as the retry action

### AI Strategy Review results — P/E
- Loading state (see cross-cutting): skeleton/spinner while the AI call is in flight
- Strategy title header
- Review block (clarity/consistency notes)
- Flagged rules list (each with a short excerpt + issue)
- "Re-run" / "Dismiss" buttons
- Error state (see cross-cutting): if the AI call fails

### AI Journal Analysis results — P/E
- Loading state (see cross-cutting): skeleton/spinner while the AI call is in flight
- Top bar: back, title
- Date range picker + strategy filter (top, collapsible)
- Pattern summary card(s): recurring mistakes, psychology trends, tag/outcome correlations
- Disclaimer footnote
- No entries in the selected range/strategy filter: standard empty state (see cross-cutting) — "No entries in this range to analyze" → CTA to widen the date range, not to create a new entry (this screen doesn't create data, it reads it)
- Error state (see cross-cutting): if the AI call fails

### Weekly / Monthly Performance Review — P/E
- Loading state (see cross-cutting): skeleton/spinner while the AI call is in flight
- Period segmented control
- Narrative summary card
- Key stat chips pulled from Portfolio Dashboard
- Disclaimer footnote
- Error state (see cross-cutting): if the AI call fails

### Daily Digest — P/E
- Loading state (see cross-cutting): skeleton on open
- Top movers list (ticker, change %, tap → Ticker Detail)
- AI summary card
- Disclaimer footnote
- Error state (see cross-cutting): if the digest fails to load

---

## 9. Notifications

### Notification Center — F/P/E
- Loading state (see cross-cutting): skeleton notification rows on open
- Top bar: title "Notifications", "Mark all read" text button
- Grouped list by category (section headers: Market Alerts, Community, Messages, Strategy, AI, Subscription)
- Notification rows: icon (by category), title, body snippet, relative timestamp, unread dot
- Tap row → deep link to relevant screen (see DYNAMIC_LINKING.md)
- Empty state (see cross-cutting)
- Error state (see cross-cutting): if the notification list fails to load

### Notification Preferences — F/P/E
- Loading state (see cross-cutting): skeleton toggle rows on open (brief — this is a small, mostly-static list)
- Top bar: back, title
- List of category rows, each with: label, push toggle, in-app-only fallback note
- Toast (see cross-cutting): confirms a toggle change saved, or shows an error toast if it fails to persist

---

## 10. Subscriptions

### Plan Comparison / Paywall — All
- Top bar: close "×" (top-right)
- Billing-cycle segmented control (Monthly/Annual) — shown above Premium column
- Horizontally swipeable or stacked plan cards: Free / Premium / Enterprise
- Feature checklist per card (checkmark/lock icons)
- Premium card: price, "Upgrade" button (primary, prominent)
- Enterprise card: "Contact Us" button (secondary)

### Upgrade / Checkout — All
- Native purchase sheet (platform-provided on iOS/Android) or in-app Stripe sheet (web-equivalent on Flutter web)
- Plan/cycle/price recap
- Success sub-screen: checkmark animation, "You're on Premium" message, "Continue" button
- Error sub-screen: error message, "Try Again" / "Contact Support"

### Manage Subscription — P/E
- Loading state (see cross-cutting): skeleton for the current-plan card on open
- Top bar: back, title
- Current plan card (name, cycle, renewal date)
- "Change Plan" row → Plan Comparison
- "Cancel Subscription" row (destructive style, opens confirmation dialog, deep-links to store management on iOS/Android)
- Billing history list (web only)
- Error state (see cross-cutting): if subscription details fail to load
- Toast (see cross-cutting): confirms cancellation was processed

---

## 11. Enterprise (post-MVP)

**Reminder from ARCHITECTURE.md § 4 / ROADMAP.md:** the `organizations`, `organization_members`, and `api_keys` data model doesn't exist yet — the component detail below is a design-level spec to build toward, not something implementable against a real backend contract today. Treat field names here as provisional until the schema is actually specced.

### Org Dashboard — E
- Loading state (see cross-cutting): skeleton for the quick-link cards on open
- Top bar: org logo (small, left) + org name, settings gear icon (top-right) → org-level settings (rename org, delete org — destructive, behind confirmation)
- Member count summary row ("12 members, 2 pending invites") — tap → Team Management
- Quick-link cards (2-column grid): Team Management, Admin Controls, Organization Analytics, Branding Settings, API Access — each card shows an icon, label, and a one-line status ("3 pending approvals" on Admin Controls, "Last updated 2 days ago" on Branding)
- Seat usage indicator (e.g. "12 of 20 seats used") if the Enterprise plan is seat-limited — tap → upgrade seat count flow (billing, out of this screen's direct scope but linked)
- Empty state: not applicable — an org always has at least the creating admin as a member
- Error state (see cross-cutting): if org data fails to load

### Team Management — E
- Loading state (see cross-cutting): skeleton member rows on open
- Top bar: back, title "Team", search icon (expands to filter member list by name/email)
- Role filter chip row (All / Admin / Member / Pending)
- Member list rows: avatar, name + email, role chip (tap chip → role picker, inline), seat status badge (Active / Pending invite / Suspended)
- Swipe-left on row → Remove (confirmation dialog: "Remove [name] from the team? They'll lose access immediately.")
- FAB: "+" → Invite Member bottom sheet: email field (supports comma-separated multi-invite), role picker (Admin / Member), optional welcome-message text field, "Send Invite(s)" button
- Pending invite rows show a "Resend" text action and an expiry indicator ("Invite expires in 5 days")
- Empty state: not applicable beyond the creating admin, but a fresh org shows a prominent "Invite your team" CTA above an otherwise single-row list
- Error state (see cross-cutting): if the member list fails to load
- Toast (see cross-cutting): confirms invite sent, member removed, or role changed

### Admin Controls — E
- Loading state (see cross-cutting): skeleton for each section on open
- Top bar: back, title "Admin Controls"
- Section: **Feature toggles** — list of org-wide feature flags (e.g. "Allow members to post publicly outside the org," "Require AI disclaimer acknowledgment") — each a labeled toggle row
- Section: **Moderation queue** — list of flagged org-internal content (if org-internal posting/commenting exists), each row: flagged item preview, reporter, "Review" button → review sub-screen (approve / remove / escalate)
- Section: **Device licensing** — list of registered devices per seat (device name, platform, last active), "Revoke" swipe action per row, relevant if the Enterprise plan ties seats to specific devices rather than floating licenses
- Empty states per section independently (e.g. "No flagged content" for an empty moderation queue) rather than one screen-level empty state, since sections are independently populated
- Error state (see cross-cutting): per-section, if any one section's data fails to load independently of the others
- Toast (see cross-cutting): confirms a feature toggle change, a moderation decision, or a device revocation

### Organization Analytics — E
- Loading state (see cross-cutting): skeleton stat cards + chart on open
- Top bar: back, title "Analytics", export icon (CSV/PDF export — future, may be a locked/upsell affordance even within Enterprise if it's a higher-tier add-on)
- Date range control (segmented: 7d / 30d / 90d / Custom)
- Aggregate stat cards (2×2 or scrollable row): Active Members (this period), Total Journal Entries Logged, Total AI Calls (all types combined), Community Engagement (posts+comments+likes org-wide)
- Per-member breakdown table (below the stat cards): member name, activation status, entries logged, AI usage — sortable columns, matches the dense-data-table pattern rather than card-based (this is the one Enterprise screen closest in spirit to Watchlist Detail's row-dense layout)
- Chart: org-wide activity trend line over the selected date range (reuses `THEquityCurveChart`'s line-chart styling, different data source)
- Empty state: "No activity in this range" if the date filter returns nothing
- Error state (see cross-cutting): if the analytics query fails

### Branding Settings — E
- Loading state (see cross-cutting): skeleton for current logo/theme/domain values on open
- Top bar: back, title "Branding"
- Logo upload row: current logo preview (or placeholder), "Change" button → image picker bottom sheet, recommended-dimensions helper text
- Color theme picker: a small set of preset accent-color swatches (not full custom color picker for MVP-of-Enterprise scope — keeps this from becoming its own mini design tool) — selected swatch previews live against a sample card/button
- Custom domain field (web-relevant primarily): text input + "Verify" button, DNS instructions link, status indicator (Unverified / Verifying / Active)
- Preview panel (persistent, right side on tablet/desktop per SCREENS_TABLET.md § 2 pattern; a "Preview" button opening a full-screen preview on mobile given space constraints) showing how the org's branding renders in-app
- "Save" button (bottom-pinned on mobile), disabled until a change is made
- Error state (see cross-cutting): if current branding fails to load, or if save/verify fails
- Toast (see cross-cutting): confirms branding saved

### API Access / Key Management — E
- Loading state (see cross-cutting): skeleton key rows on open
- Top bar: back, title "API Keys", info icon → brief explainer sub-screen on what API access enables (links out to API documentation, not built here)
- Key list rows: key name, scope badge (Read-only / Full access), created date, last-used relative timestamp, status dot (Active / Revoked, revoked keys shown greyed-out rather than removed, for audit history)
- Empty state: "No API keys yet" → CTA to create one
- FAB: "+" → Create Key sub-screen: name field, scope picker (Read-only / Full access — expand to granular per-resource scopes post-MVP-of-Enterprise if needed, flagged as a future refinement not required for launch), "Create" button
- One-time reveal screen (immediately after creation): key value in a monospace field with a "Copy" button and a prominent warning ("This key won't be shown again — copy it now"), "Done" button
- Swipe-left on an active key row → "Revoke" (confirmation dialog: "Revoke this key? Any integration using it will stop working immediately.")
- Usage log link per key (tap key name, not the row itself) → a simple chronological request log sub-screen (timestamp, endpoint called, response status) — read-only, no filtering needed at MVP-of-Enterprise scope
- Error state (see cross-cutting): if the key list fails to load
- Toast (see cross-cutting): confirms key creation, "Copied to clipboard" on the one-time reveal screen, and confirms revocation
