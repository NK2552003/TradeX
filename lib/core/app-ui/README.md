# app-ui — reusable component inventory

Domain layer for the trading app, built **entirely** on the shared `flutter-ui`
kit. Dart-only, dark-first, responsive on phone / tablet / desktop.

Import everything through one surface:

```dart
import 'package:your_app/app-ui/app_ui.dart'; // re-exports flutter-ui too
```

Rules this layer follows:

- No raw colors. Everything resolves from `UiTheme` / `AppTokens`.
- No layout duplication. Sizing goes through `context.sp/sz/radius` and
  `context.uiRes.pick(...)` so a component works on every device.
- Presentation-only. Widgets take models and callbacks, never fetch data.

---

## 1. Foundations

| Component | File | Purpose |
| --- | --- | --- |
| `AppTokens` | `theme/app_tokens.dart` | P/L colors + intents, tier tokens, sentiment, side/outcome, money / percent / R / relative-time formatting |
| `AppTier`, `AppTrend`, `AppSentiment`, `AppSide`, `AppOutcome` | `theme/app_tokens.dart` | Domain enums |
| `AppFadeIn` | `motion/app_motion.dart` | Staggered entrance (delay, offset, axis) |
| `AppCountUp` | `motion/app_motion.dart` | Animated numeric value |
| `AppHoverLift` | `motion/app_motion.dart` | Desktop-only hover lift, no-op on touch |
| `AppReveal` | `motion/app_motion.dart` | 0→1 progress driver for charts/rings |
| `AppCollapse` | `motion/app_motion.dart` | Animated expand/collapse |
| `AppLogoMark`, `AppWordmark`, `AppSplashMark` | `brand/app_logo.dart` | Custom-painted brand marks |
| Models | `models/app_models.dart` | `AppTrade`, `AppStrategy`, `AppStrategyVersion`, `AppTicker`, `AppPriceAlert`, `AppStat`, `AppSeriesPoint`, `AppDayPnl`, `AppTrader`, `AppPost`, `AppComment`, `AppConversation`, `AppChatMessage`, `AppAiInsight`, `AppNewsItem`, `AppNotification`, `AppPlan`, `AppChecklistItem`, `AppAchievement`, `AppNavItem`, `AppNavSection`, `AppCommandItem` |

## 2. Cards (24)

### Journal — `cards/journal_cards.dart`
1. `AppTradeCard` — ticker, side, P/L, R, tags; `dense` variant for lists
2. `AppPnlSummaryCard` — period P/L with delta and sparkline
3. `AppLessonCard` — takeaway / lesson learned
4. `AppScreenshotImportCard` — AI screenshot-to-trade import with states
5. `AppChecklistCard` — reusable checklist card
6. `AppPsychologyCard` — emotional discipline score
7. `AppTradeCardSkeleton` — loading placeholder

### Strategy — `cards/strategy_cards.dart`
8. `AppStrategyCard` — name, category, visibility, version count
9. `AppStrategyPerformanceCard` — win-rate ring + net P/L + equity spark
10. `AppVersionCard` — version-history entry with restore
11. `AppStrategyComparisonCard` — head-to-head comparison
12. `AppStrategySummaryCard` — AI summary with loading state

### Market / watchlist — `cards/watchlist_cards.dart`
13. `AppTickerCard` — price, change, spark, note
14. `AppPriceAlertCard` — target, direction, distance progress, toggle
15. `AppMoverCard` — compact tile for horizontal rails
16. `AppHeatTile` — intensity-scaled heatmap cell

### Portfolio / analytics — `cards/portfolio_cards.dart`
17. `AppStatCard` — KPI tile (count-up, delta, spark)
18. `AppWinRateCard` — animated win-rate gauge + breakdown
19. `AppExtremeTradeCard` — best / worst trade
20. `AppRiskRewardCard` — avg R vs target R
21. `AppDrawdownCard` — max drawdown with area spark
22. `AppStreakCard` — discipline streak tracker
23. `AppCalendarDayCard` — one day of the P/L heatmap
24. `AppStatCardSkeleton` — loading placeholder

### Community — `cards/community_cards.dart`
25. `AppPostCard` — feed post with tickers, media, engagement
26. `AppTraderRow` — avatar + handle + tier (reused everywhere)
27. `AppTraderCard` — profile card with follow / message
28. `AppLeaderboardCard` — ranked row with podium accent
29. `AppCommentCard` — threaded comment with indent
30. `AppConversationCard` — DM inbox row with unread count
31. `AppMessageBubble` — chat bubble
32. `AppAiInsightCard` — AI insight with confidence meter
33. `AppNewsCard` — headline with sentiment tint
34. `AppNotificationCard` — notification row

### Account / billing — `cards/account_cards.dart`
35. `AppPlanCard` — subscription plan
36. `AppUsageCard` — quota meter with upgrade nudge
37. `AppTierGateCard` — locked-feature gate
38. `AppAchievementCard` — gamified badge
39. `AppSettingCard` — setting row with trailing control

## 3. Blocks (32)

Blocks are full page sections. Every one is responsive by construction.

### Dashboard — `blocks/dashboard_blocks.dart`
1. `AppStatGridBlock` — 1/2/4-column KPI grid with skeletons
2. `AppEquityCurveBlock` — equity chart + range switcher
3. `AppPnlCalendarBlock` — monthly P/L heatmap
4. `AppRecentTradesBlock` — recent trades with empty state
5. `AppMoversRailBlock` — horizontal gainers/losers rail
6. `AppAllocationBlock` — allocation donut
7. `AppBreakdownBlock` — ranked performance bar list
8. `AppDashboardLayoutBlock` — main/side responsive two-column layout

### Journal & strategy — `blocks/journal_blocks.dart`
9. `AppJournalFilterBlock` — search + outcome filters + more-filters
10. `AppTradeListBlock` — cards on phone, sortable table on wide screens
11. `AppTradeDetailBlock` — levels, result, notes, screenshot, tags
12. `AppPreTradeChecklistBlock` — checklist gate before logging a trade
13. `AppStrategyLibraryBlock` — strategy grid with empty state
14. `AppVersionHistoryBlock` — version timeline with restore

### Market — `blocks/market_blocks.dart`
15. `AppWatchlistBlock` — responsive watchlist grid (+ loading/empty)
16. `AppHeatmapBlock` — 2/3/4/6-column heatmap
17. `AppAlertsBlock` — price-alert manager
18. `AppNewsFeedBlock` — news list
19. `AppSentimentBlock` — crowd sentiment split with marker
20. `AppAiInsightsBlock` — AI insight list
21. `AppSymbolHeaderBlock` — symbol price header + timeframe switcher

### Community — `blocks/community_blocks.dart`
22. `AppComposerBlock` — post composer
23. `AppFeedBlock` — feed with loading/empty states
24. `AppSuggestedTradersBlock` — who to follow
25. `AppLeaderboardBlock` — leaderboard with period switcher
26. `AppCommentThreadBlock` — comments + inline reply
27. `AppInboxBlock` — DM inbox
28. `AppChatThreadBlock` — chat thread + composer
29. `AppNotificationsBlock` — notification center

### Account — `blocks/account_blocks.dart`
30. `AppProfileHeaderBlock` — profile header (actions reflow on mobile)
31. `AppPricingBlock` — stacked on phone, side-by-side on wide
32. `AppBillingBlock` — plan, renewal, usage meters
33. `AppSettingsSectionBlock` — grouped settings
34. `AppAchievementsBlock` — achievements wall
35. `AppAuthBlock` — sign in / sign up with social providers
36. `AppOnboardingBlock` — step list with progress

## 4. Shell — `shell/app_shell.dart`

| Component | Behaviour |
| --- | --- |
| `AppShell` | Phone: top bar + bottom dock. Tablet: icon rail. Desktop: full sidebar, collapsible. |
| `AppSidebar` | Grouped sections, collapse to icons, tooltips when collapsed |
| `AppNavTile` | Selected state, badge count, tier lock |
| `AppBottomDock` | Mobile dock with badges |
| `AppTopBar` | Search, notifications with unread dot, tier chip, avatar |
| `AppCommandPalette` | Filterable command list (⌘K on desktop, full screen on mobile) |
| `AppPageBlock` | Page scaffold: title, subtitle, actions, responsive padding |

## 5. Responsive rules used everywhere

| Breakpoint | Navigation | Grids | Tables |
| --- | --- | --- | --- |
| Phone | Bottom dock | 1 column | Stacked cards |
| Tablet | Icon rail | 2–3 columns | Table, low-priority columns hidden |
| Desktop | Sidebar | 3–4 columns | Full table + hover states |
| Large | Sidebar | 4–6 columns | Full table |
