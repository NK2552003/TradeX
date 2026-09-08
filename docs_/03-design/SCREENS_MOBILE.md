# Mobile screens (iOS and Android)
## Screen inventory, components, and states

This document serves as the baseline screen specification for mobile devices. Breakpoint adaptations for larger screens appear in [SCREENS_TABLET.md](./SCREENS_TABLET.md) and [SCREENS_DESKTOP.md](./SCREENS_DESKTOP.md). For state diagrams, see [UI_FLOW_DIAGRAMS.md](./UI_FLOW_DIAGRAMS.md). Visual design tokens are cataloged in [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md), navigation links in [DYNAMIC_LINKING.md](./DYNAMIC_LINKING.md), and product context in [PRD.md](./PRD.md).

Mobile navigation relies on a bottom tab bar with seven primary tabs (collapsible to a "More" overflow pattern), full-screen modals for creation flows, bottom sheets for quick actions, and native gestures for back-stack navigation.

The three writing destinations — journal notes (section 2), strategy notes (section 3) and trader notes (section 4) — are cross-linked in both directions. How a link is followed between them, and why the phone's document counts as a real back step, is specified in [DYNAMIC_LINKING.md](./DYNAMIC_LINKING.md) sections 2 and 3.

Tier gating shorthand: **F** = Free, **P** = Premium, **E** = Enterprise (post-MVP).

Every screen that fetches data on mount explicitly handles loading and error states. Screens with write, delete, or completion actions display toast notifications. Static forms that perform no initial network requests omit initial loading states.

---

## Cross-cutting sub-screens and states
These states recur throughout the app and share a single standard specification:

| State or sub-screen | Contents and behavior |
|---|---|
| Loading state | Skeleton placeholders matching the target screen layout rather than bare spinners |
| Empty state | Icon, one-line message, and a clear call to action |
| Error state | Warning icon, friendly error message, and a "Retry" button |
| Confirmation dialog | Title, concise explanation, "Cancel" button, and a styled destructive button |
| Image viewer lightbox | Full-screen image preview, pinch to zoom, swipe down to dismiss, and export controls |
| Bottom sheet | Drag handle, title bar, content body, and a pinned bottom action button |
| Toast notification | Bottom-anchored banner with auto-dismiss and optional undo action |
| Paywall interstitial | Modal sheet triggered when a free-tier user attempts to access a premium feature |

---

## 1. Auth and profile

### Splash and onboarding (all tiers)
- Centered application logo and wordmark
- Swipeable value-proposition carousel with five slides and page indicator dots
- Pinned bottom primary button: "Get Started"
- Secondary text link: "Log In"

### Sign up (all tiers)
- Top-left back navigation button
- Email field, password field with visibility toggle, and real-time strength meter
- Unique handle input with live availability validation
- Centered "or" divider
- Full-width "Continue with Google" button
- Full-width "Continue with Apple" button
- Terms of service and privacy policy checkbox with inline legal links
- Primary "Sign Up" button, disabled until validation rules pass
- Footer link: "Already have an account? Log In"
- Error handling: inline banners placed above the submit button to preserve entered values

### Log in (all tiers)
- Back button
- Email and password input fields
- Third-party authentication buttons for Google and Apple
- Right-aligned "Forgot password?" link beneath the password field
- Primary "Log In" button
- Footer link: "Sign Up"
- Error handling: inline alert banner for invalid credentials or network timeouts

### Forgot password (all tiers)
- Back navigation button, email input field, and "Send reset link" button
- Confirmation state replacing the form with a success checkmark and rate-limited resend option
- Error handling: inline alert banner on submission failure

### Personal profile (all tiers)
- Top navigation bar with Settings icon button
- Loading state: skeleton layout for avatar, handle, and metrics
- Avatar image with edit pencil overlay, opening image picker bottom sheet on tap
- Inline tap-to-edit fields for handle and bio
- Experience level and trading style chips that open selection sheets on tap
- Subscription tier badge routing to subscription management or upgrade flows
- Metric row showing follower and following counts, opening user lists on tap
- Public performance card displaying win rate and net P/L when sharing is enabled
- Toggle switch for public journal entry visibility
- Segmented control switching between Posts, Strategy Notes, and Public Journal entries
- Tab-specific content grid or list
- Floating action button or top action icon to create content matching the active tab
- Toast notification confirming profile updates or displaying save failures

### Public profile for another user (all tiers)
- Loading state: skeleton layout for profile card
- Back button and overflow menu for report or block actions
- Avatar, handle, bio, experience level chip, and trading style chip
- Follower and following count displays
- Public statistics card if the owner shares performance data
- Full-width primary follow/unfollow toggle button
- Secondary message button for Premium and Enterprise viewers, directing to direct messages; Free viewers see an upgrade prompt
- Segmented control switching between public Posts, Strategies, and Journals
- Content feed for the selected segment
- Error handling: standard "Profile not available" screen if user does not exist
- Toast notification confirming follow state changes or moderation actions

### Settings (all tiers)
- Notifications row opening notification preferences
- Account management rows for changing email and updating password
- Privacy section with public journal visibility toggle
- Subscription row showing current tier and linking to billing management
- Enterprise organization link, visible only to team members
- Log out button with neutral destructive styling
- Red "Delete Account" button opening a confirmation modal
- Toast notifications confirming credentials or preference updates

---

## 2. Journal notes (trading journal)

The journal destination is **one screen with three surfaces** — index, document, editor — and the phone gets a genuinely different arrangement from the desktop workbench described in [SCREENS_DESKTOP.md](./SCREENS_DESKTOP.md) section 2. Implementation: [lib/features/journal/ui/journal_screen.dart](../../lib/features/journal/ui/journal_screen.dart).

On a phone the index *is* the first screen and the entry is the second. A 340 dp rail cannot coexist with a document at 390 dp, and hiding the rail behind a button buries the list — so opening an entry is a real back step, reported to the shell through `onSubpageChanged` so the app bar names it and the hardware back gesture unwinds it.

### Journal index (Free: limited entries; Premium and Enterprise: unlimited)
- `AppJournalNoteStatRow` at the top, compact variant: total entries, open positions, net P/L, win rate, average R, entries written up, entries unfiled, and a sparkline equity curve over the filtered slice
- `AppJournalNoteFilterBar`: search field, sort selector (recent, oldest, best P/L, worst P/L), outcome filter, tag filter, ticker filter, and two switches — "needs a write-up" and "not filed under a playbook"
- Both the stat strip and the filter bar **scroll away with the list**. On a 390 dp screen a pinned header of controls leaves room for one and a half cards
- Count badge distinguishing "N shown" from "N of M" when a page limit is in effect
- Loading state: skeleton entry cards; the subtitle reads "Loading…"
- `AppJournalNoteGrid` of entry cards, optionally grouped under month headers — grouping appears only under a chronological sort, because over a list sorted by P/L a month header would misdescribe the grouping
- Each card shows ticker, side, outcome badge, net P/L, R multiple, a story excerpt, a write-up indicator, and a linked-notes count resolved through the link graph rather than read off the record
- Scroll paging: 12 entries at a time, extended when the list is within 560 dp of its end
- Empty state distinguishes "nothing matches" (offers "Clear filters") from "no entries yet" (offers "New entry")
- Floating "New entry" button (`journal_new_entry_fab`), positioned clear of the mobile dock inset
- Free-tier usage banner warning when approaching or reaching the monthly entry limit

### Journal note document (all tiers)
- Opened by tapping a card; replaces the index and takes a back step
- Header showing ticker symbol, side, outcome badge and date; the ticker is a link into instrument detail
- Trade numbers: entry, exit, stop loss, target, size, fees, net P/L and R multiple, all derived rather than retyped
- Screenshot gallery opening the lightbox viewer on tap; attachments resolve through signed URLs
- The write-up itself: what was seen, what was done, psychology, mistakes, lessons — rendered as markdown, with `tradex://` links resolved inline
- `AppLinkedRecordsPanel` naming the playbook this trade was filed under, the trader notes that discuss it, and the instrument — every tile navigable, cross-destination tiles routed through the shell
- "Same playbook" list: other trades taken under the same rules, newest first
- A broken link renders as a broken link and reports "That record is gone — the link is kept so you can see it broke" rather than disappearing
- Overflow menu for edit, delete, share and link actions; deleting returns to the index with an undoable toast
- Bottom action bar with "AI Trade Review" for Premium accounts

### Journal note editor (all tiers)
- **Opened from a template gallery, never a blank form.** A template is the fastest way to log a trade properly and the only way a trader who has never written one up learns what belongs in it
- Top bar with "Cancel" and "Save"; the editor owns the save-or-discard decision, so the shell's back button asks the editor to close rather than closing over its head
- Ticker search field with autocomplete
- "Attach screenshot" with gallery picker, upload progress, and OCR field extraction notice
- Editable trade parameters pre-filled from OCR: entry, exit, stop loss, target, size, side toggle; P/L calculated automatically with an override
- Markdown body for the write-up, with a link-insertion affordance for playbooks, notes and tickers
- Tag chip input with suggestions
- Playbook selector opening a searchable picker; the candidate list comes from `AppLinkGraph.options`
- Inline error banners if screenshot parsing or database writes fail; toast confirming saves
- Closing after a save lands on the entry just written — including one created from a template, whose id the index never saw

Sub-screen outcome override sheet provides distinct options for Win, Loss, and Breakeven alongside an automatic calculation reset.

---

## 3. Strategy notes (playbooks) and analyzer

The strategy destination mirrors the journal deliberately: the same three surfaces, the same workbench on desktop, the same replace-and-back step on a phone. Whatever a reader learns about one applies to the other. Implementation: [lib/features/strategies/ui/strategies_screen.dart](../../lib/features/strategies/ui/strategies_screen.dart).

### Playbook library (Free: locked with upsell; Premium and Enterprise: full)
- `AppStrategyNoteStatRow`: playbook count, live count, aggregate win rate, total trades, best performer
- `AppStrategyNoteFilterBar`: search, sort, status filter (draft / testing / live / retired), tag filter, ticker filter, favourites-only switch
- Loading state: skeleton cards for subscribed users
- `AppStrategyNoteGrid` of playbook cards: name, status badge, favourite toggle, win rate, trade count, R expectancy, linked-note count, and the instruments the playbook names
- **Win rate is displayed as a percentage of the 0–100 value stored on the record.** `AppStrategy.winRate` is already 0..100 while `AppJournalStats.winRate` is 0..1; the split is documented rather than unified, and a widget test fails on any percentage above 100 to catch a re-introduced `* 100`
- Scroll paging: 8 playbooks at a time
- Floating "New playbook" button (`strategy_new_fab`)
- Free-tier lock screen featuring an upgrade illustration and paywall action
- Empty state distinguishing a filtered miss from an empty library

### Strategy note document (Premium and Enterprise)
- Header with name, status selector, visibility selector and favourite star
- Performance block: win rate, trades, net P/L, average R, outcome distribution — **all derived from the journal entries filed under this playbook, never stored by hand**
- The rules themselves as markdown: entry conditions, invalidation, stop placement, sizing, exit — with `tradex://` links resolved inline
- AI summary callout with refresh action for Premium accounts
- `AppLinkedRecordsPanel` naming the trades filed under this playbook, the notes that discuss it, and the union of instruments it names and instruments it was actually traded on. A playbook written for the index that keeps getting traded on bank futures is worth seeing
- Version history entry point
- Bottom action bar with "Edit"; toasts confirm deletions, tag edits and AI summary refreshes

### Strategy note editor (Premium and Enterprise)
- **Opened from a template gallery.** A template carries the section headings a set of rules needs — entry, invalidation, stop, sizing, exit — which is the difference between a playbook and a note that says "buy breakouts"
- Navigation bar with "Cancel" and "Save"; the editor owns the dirty check
- Name field, status and visibility controls, tag and ticker inputs
- Markdown body with a toolbar docked above the software keyboard
- Autosave status indicator: Saved, Saving, or Failed, with a retry prompt if a background autosave drops connection
- Toast confirming manual version publishing

### Version history (Premium and Enterprise)
- Loading state: skeleton list of revisions
- Chronological list displaying version numbers and relative timestamps
- Tap row to preview read-only content with a pinned "Restore This Version" button
- Toast notification confirming successful version rollbacks

### Strategy analyzer (Premium and Enterprise)
- Loading state: skeleton metric cards
- Sorting controls for win rate, total profit, and total trade count
- Summary cards showing strategy name, win rate percentage, average P/L, trade volume, and outcome bars
- Tap card to open the filtered journal entries for that playbook — a cross-destination link, so it travels through the shell's `AppLinkOpenRequest`
- Empty state prompting the user to file trades under a playbook

### Linking health (all tiers, surfaced on the journal and playbook indexes)
- Unfiled trades count, tapping into the journal filtered to `onlyUnfiled`
- Entries without a write-up, tapping into `onlyUnwritten`
- Orphan records: anything with nothing attached. A trade with no plan and no note is the one that will be repeated
- Journal coverage percentage: how many entries carry a story. A journal of numbers with no words is the failure mode the whole feature exists to prevent
- Tickers are excluded from orphan detection — naming an instrument is a topic tag, not a relationship to the trader's own records

### Graph view (deferred)
Specified in [DYNAMIC_LINKING.md](./DYNAMIC_LINKING.md) section 8. The linked-records panels and linking health cards cover the MVP need; a force-directed canvas is worth building once a workspace routinely holds hundreds of edges.

---

## 4. Trader notes

The third writing surface, and the oldest of the three. Where a journal note is about one trade and a playbook is about one set of rules, a trader note is about anything else worth keeping: a market read, a checklist, a post-mortem across ten trades, a cheat sheet. Implementation: [lib/features/notes/ui/notes_screen.dart](../../lib/features/notes/ui/notes_screen.dart).

Trader notes deliberately do **not** use the workbench frame. A note has no natural index ordering to keep beside the reader the way a dated trade log or a status-grouped playbook library does, so the surface is a card grid that opens a full-width reader.

### Notes workspace (all tiers)
- `AppNoteStatRow` (a `UiStatStrip` of four): notes, this week, public, words
- Two collections behind tabs: "My notes" and "Public notes". Public notes are read-only — edit and delete controls are absent, not disabled
- `AppNoteFilterBlock` in a **pinned** sticky header (148 dp on a phone, 172 dp above): search with match highlighting, note-type filter, tag filter, sort, and a density toggle. Unlike the journal and playbook indexes, these controls stay put — the notes grid is browsed by search far more than by scroll
- Count badge distinguishing "N shown" from "N of M"
- Lazy grid of `AppNoteCard`: title, type icon, excerpt, tags, tickers, word count, read time, and engagement counters on public notes. Search terms are highlighted in place
- Loading state: skeleton cards inside the same grid geometry
- Empty state distinguishes a filtered miss (offers "Clear filters") from an empty collection (offers "New note")
- Floating "New note" button (`new_note_fab`) — an icon button on a phone, a labelled pill above it — positioned clear of the mobile dock inset
- Deleting a note shows an undoable toast

### Note reader (all tiers; public notes readable by anyone)
- Full-screen markdown document with an outline affordance ("Jump to section") that clears the mobile dock
- Metadata: note type, tags, tickers, read time, word count, created and updated timestamps
- `AppLinkedRecordsPanel` — the same panel the journal and playbook documents use. A note shows every kind it touches: trades, playbooks, other notes and instruments
- "Related notes": other notes sharing at least one tag, most overlap first
- On tablet and desktop the metadata moves into a details rail beside the body; on a phone it sits above it
- Engagement row on public notes: view count, likes, comments
- Export to PDF; share action offers "make public first" on a private note

### Note editor (all tiers)
- Writing canvas plus a details panel — "Note details" on a phone, a persistent rail on desktop
- Title, note type, tag input, ticker input, public/private toggle
- Markdown body with an AI refactor toolbar over a selection
- "Linked strategy" picker and "Link journal entry" picker, both drawing candidates from `AppLinkGraph.options` with already-attached records excluded
- `onInsertJournal` writes a `tradex://journal/<id>` markdown link at the cursor, so the reference lives in the prose rather than only in a sidebar list
- Attachment upload with progress; the returned storage path is written straight into the markdown body
- Autosave status indicator; derived counters (word count, checklist progress, has-images, has-code) are recomputed before every write

---

## 5. Watchlists

### Watchlist list (Free: one watchlist; Premium and Enterprise: unlimited)
- Loading state: skeleton cards
- Favorites preview row scrolling horizontally across the top
- Watchlist cards displaying list names and ticker counts
- Floating action button opening a watchlist creation sheet
- Empty state prompting creation of an initial watchlist
- Toast notification confirming new watchlist creation

### Watchlist detail (Free: no alerts; Premium and Enterprise: full)
- Loading state: skeleton rows
- Navigation bar showing watchlist name (tap to edit) and options menu
- Category filter chips
- Ticker rows with symbol, current price, daily percentage move, notes indicator, and favorite star
- Swipe left on ticker row to trigger delete action
- Pinned bottom button to add tickers
- Empty state prompting user to add tickers
- Toast notification offering an "Undo" action after ticker removal

### Add ticker sheet (all tiers)
- Ticker search input with live lookup
- Selection sheet for assigning categories, entering notes, and setting price alerts
- Pinned bottom action button to confirm additions
- Inline search error handling
- Toast notification confirming added tickers

### Price alert setup sheet (Premium and Enterprise)
- Directional condition toggle: Price Crosses Above or Below
- Numeric threshold price input
- Dynamic preview string clarifying alert parameters
- "Save Alert" button
- Toast notification confirming active alert setup

---

## 6. Portfolio dashboard

### Portfolio dashboard (Free: headline stats only; Premium and Enterprise: full)
- Loading state: skeleton metric cards and chart blocks
- Navigation bar with time range selector: Weekly, Monthly
- Primary metric cards: Total P/L, Win Rate, Average Risk/Reward, Maximum Drawdown
- Interactive equity curve chart plotting cumulative P/L
- Monthly growth bar chart
- Win and loss distribution chart
- Side-by-side cards highlighting best and worst trades, linking to journal entries
- Strategy performance preview section with upgrade lock for free accounts
- Placeholder chart state for accounts with fewer than five closed trades
- Pull-to-refresh dashboard metrics

### Strategy performance breakdown (Premium and Enterprise)
- Loading state: skeleton cards
- Portfolio baseline banner displaying total linked strategies and overall win rate
- Persistent sorting controls: Win Rate, Total P/L, Entry Count, or Recent Activity
- Time range filter chips matching portfolio dashboard intervals
- Performance cards featuring win rates, colored outcome segments, average P/L, trade count, and mini sparklines
- Tap card to open filtered strategy analysis
- Empty state directing users to link strategies to trades in the journal
- Pull-to-refresh metrics

---

## 7. Community

### Community feed (Free: limited reads daily; Premium and Enterprise: unlimited)
- Loading state: skeleton post cards
- Header bar with saved posts navigation icon
- Horizontal filter chips for content categories: Trade Analysis, Education, Psychology, Strategies, News, Market Discussion
- Post cards with user details, category chip, relative timestamp, body text, optional media, and interaction counters
- Pull-to-refresh feed
- Floating action button to compose new posts
- Free-tier banner tracking daily read allowance
- Empty state when active category filter contains no posts
- Toast notification confirming report and block actions

### Post detail (all tiers)
- Loading state: skeleton post and comment list
- Navigation bar with report, block, and mute actions
- Full post body with zoomable media
- Action bar showing like and bookmark buttons with live counters
- Chronological comment list showing author credentials and timestamps
- Docked bottom comment input field
- Toast notification confirming published comments

### Create post (all tiers)
- Header with "Cancel" and "Post" actions
- Required content-category selector chips
- Free-form text input area
- Optional ticker search input
- Image attachment button with photo picker and preview removal controls
- Inline error banners if post upload fails
- Toast notification on return to feed confirming publication

### Saved posts (all tiers)
- Loading state: skeleton cards
- Saved posts feed matching standard feed formatting
- Swipe action to remove saved items
- Empty state when no posts are bookmarked
- Toast notification with "Undo" action on removal

### Followers and following list (all tiers)
- Loading state: skeleton rows
- Segmented control switching between Followers and Following lists
- Search bar filtering usernames
- User rows with avatar, handle, and follow/unfollow toggle button
- Empty states tailored to each tab, pointing to the community feed on the Following tab

---

## 8. Direct messages (Premium and Enterprise)

### Direct messages list (Premium and Enterprise)
- Loading state: skeleton conversation rows
- Header with new message composer icon
- Conversation rows sorted by latest activity, displaying user avatar, handle, last message snippet, timestamp, and unread indicator
- Swipe left on conversation to mute or hide the thread locally
- Pull-to-refresh list
- Empty state prompting user to start a conversation
- Free-tier lock screen featuring direct message explanation and upgrade button
- Toast notification with "Undo" action after hiding a conversation

### Conversation detail (Premium and Enterprise)
- Loading state: skeleton chat bubbles while connecting to realtime channels
- Header with recipient avatar, handle, and options menu to block or report
- Message feed with incoming messages on the left and outgoing messages on the right, plus read receipts
- Realtime message updates via Supabase web sockets
- Docked bottom composer with text input and send button
- Tier downgrade banner replacing composer if subscription expires, keeping history readable
- Blocked conversation notice replacing composer if either user blocks the other
- Initial empty conversation prompt inviting the user to say hello
- Subtle reconnecting banner if realtime socket drops connection
- Message-level failure indicator with tap-to-retry action

### New message composer (Premium and Enterprise)
- Navigation bar with "Cancel" button
- Search field matching user handles with follower status badges
- Loading state: inline spinner in search results
- Tap user to open an existing thread or start a new conversation
- Free tier blocks access to this screen through upgrade interstitials

---

## 9. AI trading assistant

### Ticker search and detail (Free: basic analytics; Premium and Enterprise: full)
- Persistent search bar in navigation header
- Loading state: skeleton chart and indicator panels
- Candlestick price chart with timeframe selector
- Indicator toggles for RSI, MACD, and moving averages
- News and sentiment summary card with expansion trigger
- Pinned bottom action button: "Ask AI about this ticker"
- Free tier displays basic chart and indicators while locking sentiment and AI features behind paywalls

### AI trading assistant chat (Premium and Enterprise)
- Navigation bar with scope selector: Current Ticker, Active Watchlist, or Full Portfolio
- Conversational chat stream with legal disclaimer footers on AI messages
- Quick prompt chips: Risk/Reward, Watchlist Insights, General Question
- Docked bottom message input field
- Loading state: animated typing indicator during AI response streaming
- Inline retry button on message failure

### Trade review results (Premium and Enterprise)
- Loading state: skeleton layout during AI analysis processing
- Trade summary banner showing ticker, outcome, and P/L
- Structured AI review comparing execution against planned rules
- Regulatory disclaimer footer
- Action buttons to re-run analysis or dismiss

### AI strategy review results (Premium and Enterprise)
- Loading state: skeleton layout during processing
- Strategy title header
- Structural review notes covering logic, clarity, and consistency
- Bulleted list highlighting conflicting rules or ambiguities
- Re-run and dismiss action buttons

### AI journal analysis results (Premium and Enterprise)
- Loading state: skeleton panels during data aggregation
- Collapsible date range and strategy filters
- Behavioral pattern cards identifying repeated mistakes, emotional triggers, and outcome trends
- Disclaimer footer
- Empty state prompting user to expand date filters if no qualifying trades exist

### Weekly and monthly performance review (Premium and Enterprise)
- Loading state: skeleton cards during report generation
- Segmented control selecting weekly or monthly review periods
- AI narrative evaluation summarizing performance trends
- Key statistic chips pulled directly from the portfolio dashboard
- Regulatory disclaimer footer

### Daily digest (Premium and Enterprise)
- Loading state: skeleton cards
- Top market movers list with percentage changes, linking to ticker details
- Concise AI summary briefing
- Disclaimer footer
- Push notification entry point opening this screen directly

---

## 10. Notifications

### Notification center (all tiers)
- Loading state: skeleton notification rows
- Header with "Mark all read" button
- Categorized notification list: Market Alerts, Community, Messages, Strategy, AI, Subscription
- Notification rows with category icons, title, description preview, timestamp, and unread marker
- Tap notification to navigate directly to related screens
- Empty state view when no notifications are present

### Notification preferences (all tiers)
- Loading state: skeleton toggle rows
- List of alert categories with push notification toggles and in-app delivery notices
- Toast notifications confirming saved preference updates

---

## 11. Subscriptions

### Plan comparison and paywall (all tiers)
- Top close button
- Monthly and annual billing toggle placed above premium options
- Comparison cards for Free, Premium, and Enterprise plans
- Itemized feature lists with checkmark indicators
- Primary "Upgrade" button on the Premium card
- Secondary "Contact Us" button on the Enterprise card

### Upgrade and checkout (all tiers)
- Native payment sheet on iOS and Android, or Stripe checkout on web
- Billing cycle and price breakdown
- Post-purchase success screen with account confirmation
- Error handling screen with retry and support links

### Manage subscription (Premium and Enterprise)
- Loading state: skeleton card for active subscription details
- Subscription summary card displaying plan tier, billing frequency, and next renewal date
- "Change Plan" link opening plan comparison
- "Cancel Subscription" option opening a confirmation modal with store management deep links
- Billing receipt list on web
- Toast notification confirming plan adjustments

---

## 12. Enterprise (post-MVP)

The organization, membership, and API key models represent post-MVP designs. Schema specifications and field definitions remain provisional until backend development begins.

### Organization dashboard (Enterprise)
- Loading state: skeleton card layout
- Organization logo, company name, and settings gear linking to organization settings
- Member summary row showing total count and pending invites, linking to team management
- Two-column quick links grid: Team Management, Admin Controls, Organization Analytics, Branding Settings, API Access
- Seat utilization meter tracking allocated licenses
- Organization settings supporting workspace renaming and deletion workflows

### Team management (Enterprise)
- Loading state: skeleton member rows
- Header search bar filtering member directory by name or email address
- Role filter chips: All, Admin, Member, Pending
- Member directory rows displaying avatar, name, email, role badge, and status indicator
- Swipe left on member row to remove user with confirmation modal
- Floating action button opening an invitation sheet with email fields, role selector, and welcome message
- Resend and expiration notices on pending invitations
- Contextual invitation prompt when an organization has only one active member

### Admin controls (Enterprise)
- Loading state: skeleton section cards
- Organization feature flags controlling public sharing and compliance disclaimers
- Moderation queue listing flagged internal content with approve and remove options
- Device licensing table tracking active devices per seat with remote revocation actions
- Independent empty states and error recovery for each admin panel section
- Toast notifications confirming flag modifications and moderation actions

### Organization analytics (Enterprise)
- Loading state: skeleton metric cards and charts
- Header export button for CSV or PDF reports
- Time range filter: 7 days, 30 days, 90 days, Custom
- Aggregated metric cards tracking active members, journal volume, AI queries, and team engagement
- Sortable tabular breakdown listing per-member activity and platform usage
- Activity line chart plotting member engagement trends over time
- Empty state when selected date range contains no recorded activity

### Branding settings (Enterprise)
- Loading state: skeleton preview panels
- Logo management row with preview, upload trigger, and dimension guidance
- Curated color theme palette previewing accent colors against sample UI cards
- Custom web domain configuration field with verification status and DNS guidance
- Split-panel live preview on large screens or preview modal on mobile devices
- Pinned bottom save button, enabled when modifications exist
- Toast notification confirming branding updates

### API access and key management (Enterprise)
- Loading state: skeleton key rows
- Header information button explaining API integration capabilities
- Key directory displaying key name, scope badge, creation date, last used date, and status dot
- Empty state prompting creation of initial API credentials
- Floating action button opening key generation form with name and permission scope fields
- One-time key display screen presenting unmasked secret token with copy button and warning notice
- Swipe action to revoke active API keys with confirmation prompt
- Dedicated request log view showing timestamps, endpoints, and response status codes
- Toast notifications confirming key creation, clipboard copies, and key revocations
