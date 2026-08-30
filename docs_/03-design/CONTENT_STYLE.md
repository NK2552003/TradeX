# Content Style Guide — TraderHub
## Tone of Voice, Microcopy Patterns, and Terminology

How TraderHub talks to the user — every button label, empty state, error message, and notification in the app should read as if written by the same person. Companion to [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) (visual voice) and [SCREENS_MOBILE.md](./SCREENS_MOBILE.md) (where each piece of copy lives).

### 1. Tone of Voice
- **Direct, not hyped.** This is a financial record-keeping and analysis tool — avoid exclamation points, "🚀"-style enthusiasm, or gamified praise language ("Great trade! 🔥"). A trader's worst days happen in this app too; tone has to hold up on a loss entry the same as a win.
- **Plain English over jargon**, except where trading terminology *is* the plain English for this audience (RR, P/L, stop loss are fine — they're the user's own vocabulary; don't over-explain them).
- **Second person, active voice.** "You've hit your daily read limit," not "The daily read limit has been reached."
- **Confident, not commanding.** Suggest, don't order: "Consider linking a strategy" reads better than "You must link a strategy."
- **Never dispense financial advice in copy** — this applies to every string in the app, not just AI-generated content. UI copy should never say things like "This looks like a good entry" — save opinions on trade quality entirely for AI outputs, which already carry the mandatory disclaimer (§ 5).

### 2. Capitalization & Formatting Conventions
- **Buttons:** Sentence case, verb-first where possible ("Save entry", not "Save Entry" or "Entry Saved"). Exception: platform-native buttons (native iOS/Android purchase sheets) follow OS convention, not this rule.
- **Screen titles / nav labels:** Title Case ("Journal", "Strategy Notes", "Portfolio").
- **Section headers within a screen:** Sentence case ("Trading psychology", not "Trading Psychology").
- **Numbers:** Always use digits, never spell out ("3 entries left", not "three entries left") — this is a data-dense app, digits scan faster.
- **Currency:** Follow DESIGN_SYSTEM.md § 13 chart formatting rules everywhere currency appears, not just in charts (e.g. Journal Entry Detail's P/L field, Portfolio Dashboard stat cards).
- **Dates:** Relative for anything within 7 days ("2 days ago", "Yesterday"), absolute (`Jul 30, 2026`) beyond that — applies to journal entries, posts, notifications, version history.

### 3. Terminology Glossary
Use these terms consistently — the alternatives listed are what NOT to use, since they appear as tempting synonyms but create inconsistency across screens:

| Canonical term | Do not use |
|---|---|
| Journal entry | Trade log, trade entry, log entry |
| Strategy Note | Strategy doc, playbook, strategy page |
| Outcome (win / loss / breakeven) | Result, status |
| Watchlist item | Watched ticker, tracked stock (item can be any asset class, not just stocks) |
| Post | Update, share (as a noun) |
| Save (Community bookmarks) | Bookmark (as a verb in-app; "Saved Posts" is the screen name, keep "Save" as the button verb) |
| Public / Private (visibility) | Shared / Hidden |
| Upgrade | Subscribe, buy Premium (in-app CTA copy — "Upgrade" implies moving to something better, fits the tone better than a transactional "Buy") |
| Ticker | Symbol, stock (again, asset-class-neutral — TraderHub covers forex/crypto too per PRD.md § 4 Target Users) |

### 4. Microcopy Patterns

**Empty states** — one line describing the absence + a CTA verb, never apologetic:
- Journal List: "No journal entries yet" → "Create your first entry"
- Strategy List: "No strategies yet" → "Write your first strategy"
- Watchlist List: "No watchlists yet" → "Create a watchlist"
- Community Feed (filtered, no results): "No posts in this category yet"
- Saved Posts: "Nothing saved yet" → "Browse Community"
- Notification Center: "You're all caught up"

**Error states** — what happened + what to do, never a raw technical error:
- Network/fetch failure: "Couldn't load this — check your connection" → Retry
- Not found / no access: "This entry isn't available" (deliberately vague for private-content-not-found vs. deleted, to avoid leaking existence of private data)
- Form validation: inline, specific ("Enter a valid ticker symbol", not "Invalid input")

**Confirmation dialogs** — state the consequence, not just the action:
- Delete journal entry: "Delete this entry? This can't be undone." (not just "Are you sure?")
- Cancel subscription: "Cancel Premium? You'll lose AI Trading Assistant, unlimited entries, and Strategy Notes at the end of your billing period."
- Log out: no scary framing needed — "Log out?" is sufficient, this is a low-stakes action

**Toasts/confirmations** — short, past tense, include Undo where the action is reversible:
- "Entry saved"
- "Entry deleted — Undo"
- "Strategy published" (on setting visibility to public)

**Upsell copy** — name the specific feature just hit, never generic:
- "Strategy Notes is a Premium feature" (not "Upgrade to unlock more")
- Always pairs with what they get, not just what's locked: "Upgrade to Premium for unlimited Strategy Notes, AI insights, and more"

**AI disclaimer footer** — exact required string (PRD.md § 7, SECURITY_COMPLIANCE.md § 5), never paraphrased or shortened per-screen: *"This is AI-generated educational content, not financial advice."* Appears on every AI Trading Assistant, AI Strategy Review, AI Journal Analysis, Trade Review, and Performance Review output.

**Notification copy** — lead with the specific trigger, not the category:
- Market alert: "AAPL crossed $230.00" (not "Price alert triggered")
- Community update: "Sam liked your post" / "New comment on your post"
- Strategy reminder: "Revisit your Breakout strategy — 5 new entries linked"
- AI recommendation: "Your weekly performance review is ready"
- Subscription: "Your Premium renews in 3 days"

### 5. Compliance-sensitive copy
Two rules that apply everywhere, not just in one screen:
- Never phrase UI copy as a recommendation ("You should sell" is never acceptable, even in an AI-adjacent screen's surrounding chrome — the AI's own output is the only place opinion-adjacent language is permitted, and even there it carries the disclaimer).
- Every screen that surfaces AI-generated content must show the disclaimer from § 4 — this is a hard requirement, not a style preference; see SECURITY_COMPLIANCE.md § 5.
