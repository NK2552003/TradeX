# TradeX content style guide
## Tone of voice, microcopy patterns, and terminology

This guide establishes copy standards across button labels, empty states, validation messages, and system notifications. It serves as a companion to [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) and [SCREENS_MOBILE.md](./SCREENS_MOBILE.md).

### 1. Tone of voice
- Direct and composed: Avoid exclamation points, rocket emojis, and gamified praise. A trader's worst drawdowns occur in this application; copy must remain calm and objective during both losses and wins.
- Accessible language over unnecessary jargon: Use standard trading terms (such as RR, P/L, and stop loss) directly without over-explaining, but keep UI guidance plain and concise.
- Second person, active voice: Write "You reached your daily read limit" rather than "The daily read limit has been reached."
- Advisory rather than demanding: Suggest actions with "Consider linking a strategy" rather than "You must link a strategy."
- Never dispense financial advice in interface copy: UI copy must never instruct the user on whether to trade. Objective analysis belongs strictly in AI outputs accompanied by mandatory disclaimers.

### 2. Capitalization and formatting conventions
- Buttons: Sentence case, starting with an active verb ("Save entry" rather than "Save Entry"). Native purchase dialogs follow OS conventions.
- Screen titles and primary navigation: Title Case ("Journal", "Strategy Notes", "Portfolio").
- Sub-headings within screens: Sentence case ("Trading psychology" rather than "Trading Psychology").
- Numeric figures: Always use digits rather than spelling out words ("3 entries left" rather than "three entries left") for rapid scanning.
- Currency amounts: Follow currency formatting rules from section 13 of [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md).
- Timestamps: Use relative dates within 7 days ("2 days ago", "Yesterday") and absolute calendar dates (Jul 30, 2026) thereafter.

### 3. Terminology glossary

| Canonical term | Avoid using | Rationale |
|---|---|---|
| Journal entry | Trade log, trade entry, log entry | Standardizes primary trade record naming. |
| Strategy Note | Strategy doc, playbook, strategy page | Distinguishes rich strategy documents. |
| Outcome (win, loss, breakeven) | Result, status | Aligns with trading performance tracking. |
| Watchlist item | Watched ticker, tracked stock | Neutral across equities, crypto, and forex. |
| Post | Update, share (as noun) | Standardizes social feed entity names. |
| Save (Community bookmarks) | Bookmark | Keeps the action verb "Save" consistent with "Saved Posts". |
| Public / Private | Shared / Hidden | Matches database visibility fields. |
| Upgrade | Subscribe, buy Premium | Focuses on unlocking advanced capabilities. |
| Ticker | Symbol, stock | Broad asset class coverage across asset types. |

### 4. Microcopy patterns

#### Empty states
Provide a concise explanation of absence followed by a clear action verb:
- Journal List: "No journal entries yet" followed by "Create your first entry"
- Strategy List: "No strategies yet" followed by "Write your first strategy"
- Watchlist List: "No watchlists yet" followed by "Create a watchlist"
- Filtered Community Feed: "No posts in this category yet"
- Saved Posts: "Nothing saved yet" followed by "Browse Community"
- Notification Center: "You're all caught up"

#### Error states
State what occurred and offer an immediate remedy:
- Network failures: "Couldn't load data. Check your connection." followed by Retry
- Missing or private records: "This entry is unavailable" (intentionally vague to protect private record existence)
- Form validation: Specific inline error text ("Enter a valid ticker symbol" rather than "Invalid input")

#### Confirmation dialogs
State the consequence clearly rather than asking generic questions:
- Deleting journal entries: "Delete this entry? This action cannot be undone."
- Canceling subscriptions: "Cancel Premium? Access to the AI assistant, unlimited journal entries, and Strategy Notes ends with your billing period."
- Logging out: "Log out of your account?"

#### Toasts and confirmations
Short, past tense notices offering undo actions where reversible:
- "Entry saved"
- "Entry deleted. Undo"
- "Strategy published"

#### Upgrade prompts
Specify the exact capability requested rather than generic marketing:
- "Strategy Notes is a Premium feature."
- "Upgrade to Premium for unlimited Strategy Notes, AI insights, and full portfolio analytics."

#### AI disclaimer footer
Every AI response must display this exact educational notice:
*"This is AI-generated educational content, not financial advice."*
Display this notice on all AI Trading Assistant, Strategy Review, Journal Analysis, and Performance Review screens.

#### Notification copy
Lead with the triggering event:
- Market alert: "AAPL crossed $230.00"
- Community: "Sam liked your post"
- Strategy reminder: "Revisit your Breakout strategy: 5 new entries linked"
- AI recommendation: "Your weekly performance review is ready"
- Subscription: "Your Premium renews in 3 days"

### 5. Compliance guidelines
- Never phrase UI copy as an investment instruction. Copy must never state "You should buy" or "Time to take profits."
- Every screen presenting AI-generated analysis must display the educational disclaimer defined in section 4.
