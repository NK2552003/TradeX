# Product requirements document
## TradeX: AI trading, journaling, and community platform

### 1. Overview
TradeX is a cross-platform Flutter application (iOS, Android, Web, and Desktop) built for active traders, organized around five core pillars:

1. **AI Trading Assistant**: market analysis, trade setup explanations, risk-to-reward calculations, post-trade reviews, strategy audits, and market sentiment summaries.
2. **Trading Journal and Strategy Notes**: private trade logging linked to tickers, rich strategy documents with revision history, a strategy performance analyzer, and a relational graph view.
3. **Watchlists**: symbol tracking with threshold alerts, custom notes, and asset categories.
4. **Portfolio Dashboard**: aggregate analytics across trade records, including profit and loss, win rates, drawdown, and equity curves.
5. **Community**: a social feed for trade ideas and technical discussions, plus direct messaging between paid subscribers.

A unified notifications system supports the platform through price alerts, community updates, strategy reminders, and subscription notices.

Monetization follows a tiered subscription model (Free, Premium, and Enterprise).

The platform aims to combine technical intelligence, journaling, analytics, and community in one workspace to support disciplined decision-making.

### 2. Goals
- Deliver a functional MVP within 6 to 10 weeks.
- Validate subscriber willingness to pay for AI-generated trade insights combined with community features.
- Maintain low infrastructure costs before revenue through managed, usage-based backend services.

### 3. Non-goals (MVP)
- Direct trade execution or brokerage order routing (planned for future phases).
- Training custom machine learning models (leverage established LLM APIs and standard technical indicators).
- Group messaging or multi-party chat (direct messages are strictly one-on-one in v1).
- Copy trading, automated trade execution, or public strategy marketplaces in v1.
- Licensed financial advice (all insights are educational and informational).
- Enterprise team management and custom organizational branding (defined for scope planning, built post-MVP).

### 4. Target users
- Traders across equities, foreign exchange, commodities, options, and cryptocurrencies.
- Swing traders, day traders, and scalpers.
- Retail traders who want structured journaling, peer discussions, and quick AI setup reviews.
- Professional trading groups and prop trading firms seeking managed team dashboards (post-MVP).

### 5. Core features by module

#### 5.1 Auth and profile
- Email with password, plus OAuth options for Google and Apple.
- Public trader profile: avatar, handle, bio, experience level, trading style, follower counts, and optional public statistics (see section 5.5).
- Public journals (optional): users can choose to share selected trade entries on their profile.
- Account settings: subscription management and notification preferences.

#### 5.2 Trading journal
The trading journal provides private trade logging alongside public community sharing:
- Create, edit, and delete journal records.
- Optional ticker symbols (such as $AAPL).
- Trade fields: entry price, exit price, stop loss, profit target, position size, trade direction, and realized profit or loss.
- Screenshot attachments: one or more chart or trade images per entry.
- Unstructured execution notes.
- Trading psychology notes recording emotional state and execution context.
- Mistake categorization and lessons learned.
- Relational link to an associated Strategy Note (see section 5.3).
- Free-form tags.
- Search and filtering across tickers, dates, tags, strategies, and trade outcomes.
- Free tier includes entry limits; Premium accounts receive unlimited entries.
- Screenshot auto-fill: uploading a chart or trade confirmation triggers Claude vision parsing to extract symbol, prices, position size, and outcome for user review before saving.

#### 5.3 Strategy notes
Traders document setups as standalone rich documents:
- Formatted text editor supporting headings, lists, and callouts.
- Embedded charts and setup images.
- Version history retaining past revisions with one-click restore.
- User-defined strategy categories (such as Breakouts or Mean Reversion).
- Bookmarked favorites for fast navigation.
- Visibility options: Private (default) or Public (visible on the trader profile as read-only).
- AI summaries: Claude generates concise summaries of strategy documents, updated on edit (Premium).
- Journal entries can link directly to a parent strategy document.

#### Strategy Analyzer
- Strategy rollup: an aggregate view of all trades executed under a given strategy, calculating overall win rates, average returns, and holding periods.
- Outcome computation: calculated automatically from recorded trade profit or loss, with optional manual overrides. Screenshot parsing feeds this calculation directly.
- Classification: entries remain standard trade records whether linked to a strategy or not; unlinked trades are excluded from strategy rollups.
- Graph view: a visual network showing relationships between trades, strategies, and tickers.
- Tier access: Free accounts exclude strategy notes, analyzer views, and graph visualizations. Premium accounts have full access.

#### 5.4 Watchlists
- Multiple named watchlists (Free: 1 watchlist; Premium: unlimited).
- Add and remove tracked tickers.
- Price alerts per ticker based on price thresholds, delivered via push notifications.
- Notes per watched asset.
- Categorization tags (such as "Earnings this week").
- Quick-access favorite asset lists independent of watchlist grouping.

#### 5.5 Portfolio dashboard
An aggregate performance dashboard computed from journal records:
- Core metrics: total profit/loss, overall win rate, average risk-to-reward ratio, and maximum drawdown.
- Timeframe performance: weekly and monthly performance breakdowns.
- Performance breakdowns: strategy win rates, best trade, and worst trade.
- Charts: cumulative equity curve, monthly growth bars, and win/loss distribution.
- All metrics calculate directly from `journal_entries` without separate data entry.
- Free tier includes basic headline stats; Premium accounts receive detailed breakdowns and charts.

#### 5.6 Community
A public feed for sharing ideas and discussing market setups:
- Publish posts containing written analysis, trade ideas, and annotated chart images.
- Post classifications: Trade Analysis, Educational, Psychology, Strategy, News, and Market Discussion.
- Social interactions: likes, comments, and trader follows.
- Private bookmarks to save posts for later reference.
- Moderation tools: reporting, blocking, and muting accounts.
- Feed sorting: chronological feed of followed traders and popular tickers, filterable by post category.
- Free tier includes daily limits on reading and social interactions; Premium accounts have unrestricted access.

#### 5.7 AI trading assistant
- Ticker search returning price charts and standard indicators (RSI, MACD, and moving averages).
- Technical setup evaluations and pattern explanations.
- Risk-to-reward calculations on planned or logged executions.
- Post-trade reviews assessing completed executions against documented plans.
- Strategy suggestions combining strategy audits with cross-journal pattern analysis.
- News aggregation and market sentiment summaries.
- Watchlist commentary highlighting notable volume shifts or alert approaches.
- AI Strategy Review: automated checks for internal consistency and ambiguous execution rules (Premium).
- AI Journal Analysis: cross-journal pattern detection highlighting recurring mistakes and emotional tendencies (Premium).
- Weekly and monthly performance reviews providing narrative summaries of portfolio trends (Premium).
- Conversational Q&A assistant for trading and risk questions.
- Daily market digest push notifications (Premium).
- Free tier includes standard non-AI analytics only.
- Clear educational disclaimer on all AI outputs stating that information does not constitute financial advice.

#### 5.8 Notifications
Unified messaging system across all platform modules:
- Market alerts: price threshold notifications from watchlists.
- Community updates: follower notifications, post comments, and likes.
- Direct messages: incoming chat notifications.
- Strategy reminders: scheduled prompts to review strategies after a set number of trades.
- AI recommendations: notifications when performance digests or reviews are ready.
- Subscription notifications: renewal notices, trial expiration, and billing alerts.
- Notifications are configurable by category and delivered through push alerts and an in-app notification center.

#### 5.9 Direct messages (Premium)
One-on-one messaging provides a private communication channel between traders, accessible to paid subscribers:
- Strictly one-on-one conversations in v1 without group messaging.
- Initiate chats directly from trader profiles or an active conversation list.
- Real-time message transport, read indicators, and sorting by recent activity.
- User reporting and blocking reuses community moderation tools.
- Access gating: sending messages requires an active Premium or Enterprise plan. If a subscription lapses, the user can read existing conversations but cannot send new messages until renewed.
- Free tier users tapping message actions receive an upgrade prompt.
- Push and in-app alerts trigger on incoming messages.

#### 5.10 Subscriptions

**Free**
- Basic trader profile
- Trading journal with entry limits
- Single watchlist without threshold alerts
- Daily read limits on community posts with capped interactions
- Standard summary statistics
- No AI assistance or automated reviews
- No strategy rich text editor, analyzer, or graph view
- No direct messaging

**Premium** ($9.99 per month)
- Unlimited access to the AI trading assistant
- AI strategy audits and cross-journal pattern analysis
- Unrestricted community browsing and interaction
- One-on-one direct messaging
- Advanced portfolio analytics and full chart suites
- Unlimited watchlists with price threshold alerts
- Unlimited journal entries with automated screenshot parsing
- Strategy notes editor with revision history and graph visualization
- Priority support

**Enterprise** (custom pricing, planned post-MVP)
- Team management and seat allocation
- Consolidated organization dashboard
- Device licensing controls
- Administrative governance
- Organization-wide reporting
- Custom branding
- Dedicated API access

Subscriptions are managed through RevenueCat across mobile and web payment processors. Enterprise accounts will use direct invoicing upon release.

### 6. Success metrics (first 90 days)
- Activation: percentage of new signups logging at least one trade or publishing a post during their first session.
- Retention: day-7 and day-30 user return rates.
- Conversion: free to paid tier subscription rate.
- Engagement: average posts and comments per weekly active user.
- Journal usage: percentage of trade entries linked to strategies and graph view interactions.
- Watchlist adoption: percentage of active users tracking symbols and average tickers per watchlist.
- Portfolio engagement: weekly active users opening the analytics dashboard.
- Direct messaging: adoption rates and conversations per subscriber.

### 7. Compliance and risk controls
- Terms of service notices clarifying that TradeX is not a registered investment advisor and does not guarantee returns.
- Rate limiting and audit logging on all third-party AI requests to monitor costs and prevent abuse.
- Row-level security on all database tables, defaulting journal entries and draft strategies to private access.

### 8. Revenue model
- Monthly recurring subscription (Premium).
- Annual discounted subscription (Premium).
- Custom enterprise licensing (post-MVP).
- Optional strategy and indicator marketplace fees (post-MVP evaluation).

### 9. Release plan

| Phase | Scope | Estimated duration |
|---|---|---|
| 0 | Project scaffold, authentication, and navigation shell | 1 week |
| 1 | Trading journal CRUD and core fields | 1 to 1.5 weeks |
| 1.5 | Strategy Notes and Analyzer (editor, version history, screenshot parsing, graph view) | 1.5 to 2 weeks |
| 1.75 | Watchlists (multiple watchlists, price alerts, categories) | 3 to 5 days |
| 2 | Community feed (posts, interactions, categories, bookmarks) | 2 to 2.5 weeks |
| 2.25 | Direct messaging (one-on-one, real-time, tier gated) | 1 to 1.5 weeks |
| 2.5 | Portfolio dashboard (summary metrics, breakdowns, charts) | 1 week |
| 3 | AI trading assistant (insights, reviews, pattern analysis, Q&A) | 2 to 3 weeks |
| 3.5 | Notifications (price alerts, social, direct messages, system updates) | 3 to 5 days |
| 4 | Subscription infrastructure (RevenueCat) and paywalls | 1 week |
| 5 | Quality assurance, performance tuning, and app store submissions | 1 to 2 weeks |
| 6 (post-MVP) | Enterprise features (team administration, branding, API access) | Planned separately in ROADMAP.md |

Phases 0 to 5 cover the initial Free and Premium release, estimated at 11.5 to 16 weeks. If schedule adjustments become necessary, strategy version history and chart animations can be deferred to protect core trade logging and community functionality.

Scope note: this roadmap includes Strategy Notes and Watchlists in the MVP. If a tighter 6 to 10 week schedule is required, refer to ROADMAP.md for phased scope adjustments.
