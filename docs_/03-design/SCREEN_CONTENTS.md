# Screen contents: TradeX
## Flat reference: screen elements

This document pairs with [SCREENS_AND_FLOWS.md](./SCREENS_AND_FLOWS.md), which covers navigation and pipeline diagrams. It lists screen elements required for design layouts across the platform. Tier gating shorthand: **F** = Free, **P** = Premium, **E** = Enterprise (post-MVP). Field sources trace back to [API_DATA_MODEL.md](./API_DATA_MODEL.md).

---

## 1. Auth and profile

### Splash and onboarding (all tiers)
- App logo and wordmark
- Value proposition copy covering each pillar: AI Assistant, Journal and Strategy Notes, Watchlists, Portfolio Dashboard, Community
- Primary CTA: "Get Started"
- Secondary CTA: "Log In"

### Sign up (all tiers)
- Email field
- Password field with strength indicator
- Handle picker with live availability check
- "Continue with Google" button
- "Continue with Apple" button
- Terms of service and privacy policy checkbox (required)
- Submit button
- Link to log in

### Log in (all tiers)
- Email field
- Password field
- "Continue with Google" and "Continue with Apple" buttons
- "Forgot password?" link
- Submit button
- Link to sign up

### Forgot password (all tiers)
- Email field
- Submit button
- Post-submit confirmation message directing user to check email

### Personal profile (all tiers)
- Editable avatar or profile picture
- Editable handle
- Editable multi-line bio
- Experience level selector: beginner, intermediate, advanced, pro
- Trading style selector: day trading, swing, scalping, options, forex, crypto, other
- Subscription tier badge: Free, Premium, Enterprise
- Follower and following counters (tap to open full list)
- Public statistics block (win rate, total P/L, shown only if opted in; pulls from portfolio dashboard)
- Public journals toggle (controls whether `is_public` journal entries surface here)
- Content tabs: Posts, Strategy Notes (public), Public Journal Entries
- "Upgrade to Premium" CTA for Free tier users
- Settings button

### Public profile for another user (all tiers)
- Avatar, handle, bio, experience level, trading style
- Follower and following counts
- Public statistics block (if shared by profile owner)
- Content tabs: Posts, Public Strategy Notes, Public Journal Entries
- Follow/unfollow button
- Message button (Premium and Enterprise viewers only, direct messages in section 7; Free viewers see an upsell prompt)
- Report and block menu

### Settings (all tiers)
- Notification preferences navigation (per category, see section 8)
- Account controls: update email, update password
- Public journals visibility toggle
- Subscription management entry point
- Log out button
- Account deletion (destructive action, requires confirmation)
- Organization link for Enterprise users, routing to Org Dashboard

---

## 2. Trading journal

### Journal list (Free: limited entries; Premium and Enterprise: unlimited)
- Search bar (free text)
- Filter chips: ticker, date range, tag, strategy, outcome
- Entry cards displaying ticker, date, color-coded outcome badge (win, loss, breakeven), P/L value, and brief notes snippet
- Empty state prompting the user to log a first trade
- Floating action button: "New Entry"
- Free-tier entry count banner when approaching or at limit

### Journal entry detail (all tiers)
- Ticker with navigation link to Ticker Detail
- Entry price, exit price, stop loss, target, size, and side (long or short)
- P/L value
- Outcome badge (win, loss, breakeven), tap to open outcome override picker
- Screenshot gallery supporting multiple images with tap-to-zoom
- Trade notes
- Trading psychology section
- Mistakes made section
- Lessons learned section
- Linked strategy chip, tap to open Strategy Detail
- Tag chips
- "Make public" toggle
- Edit button and delete button (requires confirmation)
- "Link to another entry" action to create a graph edge
- Entry point to AI Trade Review for Premium users

### Journal entry creation and editing (all tiers)
- Ticker input with autocomplete
- "Attach screenshot" button with camera or gallery options
- Trade fields: entry price, exit price, stop loss, target, size, and side (pre-filled if screenshot was parsed, all editable)
- P/L field (auto-calculated from prices, supports manual override)
- Notes input field
- Psychology notes input field
- Mistakes made input field
- Lessons learned input field
- Tag input to add or remove chips
- Strategy selector (search existing or create new)
- Save and cancel buttons

---

## 3. Strategy notes and analyzer

### Strategy list (Free: locked with upsell; Premium and Enterprise: full)
- Category filter chips
- Favorite star toggle on each card
- Strategy cards showing title, category, visibility icon (private or public), and win rate summary chip if entries are linked
- Floating action button: "New Strategy"
- Navigation tabs: Analyzer and Graph View
- Free-tier locked view with upgrade banner

### Strategy detail (Premium and Enterprise, read-only preview with upsell for Free)
- Title
- Rendered rich text content with inline charts and images
- Category chip
- Favorite toggle
- Visibility toggle (private or public)
- AI summary block for Premium users with "Regenerate" option
- Linked journal entry counter, tap to open filtered Analyzer view
- Version history link
- Edit and delete buttons

### Strategy editor (Premium and Enterprise)
- Title field
- Rich text toolbar: headings, bold, italic, lists, image embed, chart embed
- Category picker (select existing or create new)
- Visibility toggle (private or public)
- Autosave draft indicator
- Save and cancel buttons

### Version history (Premium and Enterprise)
- Chronological version list with version number and timestamp
- Tap any version to preview read-only content
- "Restore this version" button, creating a new latest version from historical content

### Strategy analyzer (Premium and Enterprise)
- Per-strategy summary cards: win rate, average P/L, total entry count, and outcome distribution mini-chart
- Sorting controls by win rate, P/L, or entry count
- Tap a card to view filtered journal entries for that strategy

### Graph view (Premium and Enterprise)
- Interactive canvas displaying entry nodes, strategy nodes, and ticker nodes
- Edges showing explicit entry-to-entry links (user-drawn) and derived links to strategies or tickers
- Pinch to zoom and pan gestures
- Tap node to open detail view
- Link mode toggle to connect two entry nodes

---

## 4. Watchlists

### Watchlist list (Free: one watchlist; Premium and Enterprise: unlimited)
- Favorites shortlist at the top, independent of watchlist grouping
- Named watchlist cards showing ticker count
- Floating action button: "New Watchlist"
- Free-tier upsell banner when attempting to create additional lists

### Watchlist detail (Free: no alerts; Premium and Enterprise: full)
- Ticker rows showing symbol, latest price, and color-coded daily change
- Per-ticker notes indicator icon
- Category grouping and filter control
- Favorite star toggle on each row
- Swipe-to-remove gesture on ticker rows
- "Add Ticker" button

### Add ticker (all tiers)
- Ticker search with autocomplete
- Category assignment (pick existing or add new)
- Optional ticker note field
- Price alert toggle (enabled for Premium and Enterprise; locked with upsell for Free)

### Price alert setup (Premium and Enterprise; Free: locked with upsell)
- Threshold price input with above or below condition toggle
- Notification preview text
- Save and cancel buttons

---

## 5. Portfolio dashboard

### Portfolio dashboard (Free: headline stats only; Premium and Enterprise: full)
- Headline metric cards: Total P/L, Win Rate, Average Risk/Reward, Maximum Drawdown
- Timeframe selector: Weekly, Monthly
- Equity curve chart showing cumulative P/L over time
- Monthly growth chart
- Win/loss distribution chart
- Best trade summary card, tap to open Journal Entry Detail
- Worst trade summary card, tap to open Journal Entry Detail
- Strategy performance entry point (Premium and Enterprise; Free sees upsell prompt)

### Strategy performance breakdown (Premium and Enterprise)
- Per-strategy metrics cards: win rate, P/L, entry count
- Sorting controls by win rate, P/L, or entry count
- Tap card to open filtered Strategy Analyzer view

---

## 6. Community

### Community feed (Free: limited reads daily; Premium and Enterprise: unlimited)
- Content type filter chips: Trade Analysis, Educational, Psychology, Strategies, News, Market Discussion
- Post cards with author avatar, handle, content category badge, ticker tag if present, text body, optional image, and counts for likes, comments, and saves
- Floating action button: "New Post"
- Daily read limit banner for Free tier when near or reaching daily cap

### Post detail (all tiers)
- Full post body and attached image
- Content category badge
- Author header with avatar and handle, tap to open Public Profile
- Like button with total count
- Bookmark button with save count
- Comment thread list
- Comment input field
- Report, block, and mute menu on the author profile

### Create post (all tiers)
- Text composition area
- Content category picker (required)
- Optional ticker tag input
- Optional image or screenshot attachment
- Publish and cancel buttons

### Saved posts (all tiers)
- List of bookmarked post cards matching feed formatting
- Unsave action per card via swipe or button
- Empty state when no items are saved

### Followers and following list (all tiers)
- Search field
- User rows with avatar, handle, and inline follow/unfollow toggle

---

## 7. Direct messages (Premium and Enterprise)

### Direct messages list (Premium and Enterprise)
- New message button in header
- Conversation rows showing participant avatar, handle, snippet of latest message, relative timestamp, and unread badge
- Swipe actions: mute and hide conversation locally
- Full-screen upgrade screen on Free tier with "Unlock Direct Messages" CTA

### Conversation detail (Premium and Enterprise)
- Header with participant avatar and handle, tap to view Public Profile
- Overflow menu with mute, block, and report options
- Message bubble stream with timestamps and read receipts on sent messages
- Text composer and send button
- Resubscribe banner replacing input if the user's subscription expires
- Blocked conversation notice replacing input if either user blocks the other
- Initial empty-thread prompt encouraging conversation

### New message (Premium and Enterprise)
- User handle search field
- Result rows showing avatar, handle, and mutual follow indicator
- Tap result to open existing or new conversation

---

## 8. AI trading assistant

### Ticker search and detail (Free: basic analytics; Premium and Enterprise: full)
- Ticker search bar
- Price chart
- Core technical indicators: RSI, MACD, moving averages
- News and sentiment summary block for Premium users
- "Ask AI" button (Premium and Enterprise; Free shows upgrade modal)
- Basic analytics view for Free tier with read-only statistics and no AI narrative

### AI trading assistant chat (Premium and Enterprise; Free: locked)
- Chat stream scoped to a ticker, a watchlist, or the full portfolio using top selector
- Message input field
- Quick prompt chips: risk-to-reward analysis, watchlist insights, ask a question
- Disclaimer footer on every AI-generated response

### Trade review results (Premium and Enterprise)
- Journal entry summary header with ticker, outcome, and P/L
- AI commentary analyzing trade execution relative to plan
- Disclaimer footer
- Action buttons to dismiss or re-run analysis

### AI strategy review results (Premium and Enterprise)
- Strategy title header
- AI assessment reviewing logic, clarity, and consistency
- List of flagged ambiguities or conflicting rules
- Action buttons to dismiss or re-run analysis

### AI journal analysis results (Premium and Enterprise)
- Date range selector
- Optional strategy filter
- Pattern analysis identifying recurring mistakes, psychological trends, and tag correlations
- Disclaimer footer

### Weekly and monthly performance review (Premium and Enterprise)
- Timeframe selector: weekly or monthly
- AI narrative evaluation of trading activity
- Key figures pulled from the portfolio dashboard (Total P/L, Win Rate)
- Disclaimer footer

### Daily digest (Premium and Enterprise)
- Top market movers list
- AI summary block
- Disclaimer footer
- Push notification integration opening this screen on tap

---

## 9. Notifications

### Notification center (all tiers)
- Notification feed organized by category: Market Alert, Community Update, Strategy Reminder, AI Recommendation, Subscription Reminder
- Read and unread states on each item
- Tap notification to deep-link to relevant screen (watchlist item, post, strategy, or billing)
- "Mark all read" action
- Empty state view when no notifications exist

### Notification preferences (all tiers)
- Per-category toggles for Market Alerts, Community Updates, Strategy Reminders, AI Recommendations, and Subscription Reminders
- Delivery channel options: Push and in-app, or in-app only

---

## 10. Subscriptions

### Plan comparison and paywall (all tiers)
- Three-column matrix: Free, Premium, Enterprise
- Feature checklist per tier aligned with PRD specifications
- Monthly and annual billing toggle for Premium pricing
- "Upgrade" CTA under Premium
- "Contact us" CTA under Enterprise

### Upgrade and checkout (all tiers)
- Selected tier and billing cycle summary
- Native in-app purchase flow on mobile (App Store and Google Play) or Stripe checkout on web
- Price confirmation details
- Success and error states

### Manage subscription (Premium and Enterprise)
- Active plan name and billing cycle
- Next renewal date
- Cancellation or downgrade link (deep-links to store subscriptions on mobile)
- Billing receipt history on web

---

## 11. Enterprise (post-MVP)

### Organization dashboard (Enterprise)
- Organization name and logo
- Total member count
- Quick navigation cards: Team Management, Admin Controls, Organization Analytics, Branding Settings, API Access

### Team management (Enterprise)
- Team directory with member name, role, and seat allocation
- "Invite member" button opening invitation form with email and role selection
- Remove member action on each row
- Role assignment dropdown per user

### Admin controls (Enterprise)
- Organization feature flags
- Internal content moderation queue
- Device license management

### Organization analytics (Enterprise)
- Aggregated usage metrics across team: active members, platform engagement, AI query volume
- Date range filter

### Branding settings (Enterprise)
- Custom logo upload
- Brand color theme picker
- Custom domain configuration on web

### API access and key management (Enterprise)
- API key list: key name, permission scope, creation date, last used date
- "Create key" action displaying raw secret once before masking
- Key revocation action
- Link to API usage logs
