# TradeX feature list

This document summarizes core application features by module. Full technical requirements and specifications are defined in [PRD.md](./PRD.md). 

Tier tags:
- **F**: Free tier
- **P**: Premium tier
- **E**: Enterprise tier (planned post-MVP)

---

## Auth and profile
- Sign up and authenticate with email, Google, or Apple accounts (F)
- Public trader profile: avatar, bio, experience level, and preferred trading style (F)
- Social follows with follower and following counters (F)
- Optional public visibility for overall trading performance statistics (F)
- Granular public sharing controls for individual journal entries (F)

## Trading journal
- Trade logging: entry price, exit price, stop loss, target, position size, trade direction, and profit or loss (F, entry limits apply)
- Automated screenshot parsing: image recognition extracts trade numbers to pre-fill entry forms (F, entry limits apply)
- Structured execution notes, trade psychology observations, mistake categorization, and lessons learned (F, entry limits apply)
- Custom tags and relational links to trading strategies (F, entry limits apply)
- Full text search and multi-criteria journal filtering (F, entry limits apply)
- Unlimited journal entries (P)

## Strategy notes
- Standalone rich strategy documents supporting formatted text, charts, and embedded media (P)
- Complete version history with revision tracking and restoration (P)
- Strategy categorization and favorite bookmarks (P)
- Visibility controls to keep strategies private or publish them to trader profiles (P)
- Automatic summary generation powered by Claude (P)
- Strategy Analyzer: aggregate statistics tracking win rates and average returns per strategy (P)
- Graph view: relational node-link diagram mapping trade entries to strategies and symbols (P)

## Watchlists
- Single watchlist on Free tier (F), unlimited watchlists on Premium (P)
- Price threshold alerts with push notifications (P)
- Per-asset notes and custom asset categories (F/P)
- Quick-access asset favorites (F/P)

## Portfolio dashboard
- Aggregate statistics: total profit/loss, win rate, average risk-to-reward ratio, and maximum drawdown (F, basic metrics only)
- Periodic breakdowns for weekly and monthly performance (P)
- Comparative strategy performance rankings (P)
- Best and worst trade performance highlights (F/P)
- Visual charting: equity curves, monthly growth charts, and win/loss distributions (P)

## Community
- Public social feed for sharing market setups, annotated charts, and technical ideas (F, daily read limits apply)
- Post classification tags: Trade Analysis, Educational, Psychology, Strategy, News, and Market Discussion (F/P)
- Community engagement: likes, comments, and trader follow actions (F, daily limits apply)
- Private post bookmarks (F/P)
- User moderation: reporting, blocking, and muting accounts (F/P)
- Unrestricted feed browsing and social interactions (P)

## Direct messages
- Private one-on-one messaging between traders (P only, unavailable on Free tier)
- Real-time message delivery with read receipts (P)
- Direct message actions initiated from user profiles (P)
- Immediate mutual blocking to prevent incoming and outgoing communications (P)
- Messaging is strictly one-on-one in the initial release

## AI trading assistant
- Technical chart analysis and setup explanations on request (P)
- Trade risk-to-reward calculations and entry assessment (P)
- Post-trade review evaluating executions against planned strategy rules (P)
- Strategy consistency review to detect ambiguous rules or missing parameters (P)
- Cross-journal pattern recognition highlighting recurring trading errors and behavioral tendencies (P)
- Market news aggregation and sentiment summaries (P)
- Watchlist commentary flagging unusual volume or price movements (P)
- Automated weekly and monthly performance summaries (P)
- Interactive conversational assistant for trading inquiries (P)
- Daily market mover summaries (P)
- Free tier includes standard non-AI analytics only (F)
- Every AI response includes a disclaimer stating that content is educational rather than financial advice

## Notifications
- Push and in-app alerts: price thresholds, social interactions, direct messages, strategy review prompts, AI insights, and subscription lifecycle updates (F/P, configurable per category)

## Subscriptions
- Free: basic profile, entry-limited journal, single watchlist, rate-limited community access; AI, strategy notes, and direct messages are excluded
- Premium ($9.99 per month): complete feature set including unlimited AI, unlimited trade logs, full strategy editor, direct messaging, portfolio analytics, and custom watchlists
- Enterprise (custom pricing, planned post-MVP): team accounts, multi-user dashboard, device licensing, administrative controls, organization analytics, custom branding, and API access

---

Features excluded from MVP: group messaging, broker trade execution, copy trading, automated algorithmic order routing, and third-party strategy marketplaces.
