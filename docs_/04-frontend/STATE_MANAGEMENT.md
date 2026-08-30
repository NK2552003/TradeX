# State Management — TraderHub (Riverpod)

How data flows from Supabase into Flutter widgets, and the provider conventions every feature module should follow. Folder structure: [ARCHITECTURE.md](./ARCHITECTURE.md) § 3. Backend contracts these providers call: API_REFERENCE.md / API_DATA_MODEL.md (backend doc set).

### 1. Provider layering (per feature module)
Every `features/<module>/` folder (ARCHITECTURE.md § 3) follows the same three-layer pattern:

```
data/        -> Repository classes: raw Supabase calls (supabase_flutter SDK), one method per operation
domain/      -> Providers: wrap repositories, expose typed state to the UI (AsyncNotifier/StreamProvider/family providers)
presentation/ -> Widgets: read providers via ref.watch/ref.read, never call Supabase directly
```
**Rule:** a widget never imports `supabase_flutter` directly — always through a domain-layer provider. This keeps RLS-driven errors (403/404, ERROR_HANDLING.md backend doc) mappable to consistent UI states (SCREENS_MOBILE.md cross-cutting Error state) in one place per module instead of scattered try/catches.

### 2. Provider types by data shape

| Data shape | Provider type | Example |
|---|---|---|
| One-shot fetch, list or detail | `AsyncNotifierProvider` / `FutureProvider.family` | Journal List, Strategy Detail |
| Real-time (Supabase Realtime subscription) | `StreamProvider` | Notification Center unread count, live post likes/comments on Post Detail, Conversation Detail's live message stream (Direct Messages) |
| Local UI-only state (not persisted) | `StateProvider` / `NotifierProvider` | Filter bottom sheet selections before "Apply", form draft state, selected chart time-range toggle |
| Paginated lists | `AsyncNotifier` with a custom `loadMore()` method, not a bare `FutureProvider` | Journal List, Community Feed, Notification Center, Direct Messages List (API_REFERENCE.md backend doc § 4 pagination convention) |

### 3. Family providers for parameterized data
Any provider keyed by an ID uses `.family`: `journalEntryDetailProvider(entryId)`, `strategyDetailProvider(strategyId)`, `watchlistDetailProvider(watchlistId)`, `conversationMessagesProvider(conversationId)`. This lets Riverpod cache per-ID and auto-dispose when no widget references that ID anymore (`autoDispose` — see § 5).

### 3.1 Direct Messages — a real-time family provider, not a one-shot fetch
Worth calling out separately since it's the first genuinely live, bidirectional data surface in the app (everything else is read-mostly with occasional writes):

```dart
final conversationMessagesProvider = StreamProvider.family<List<Message>, String>((ref, conversationId) {
  return ref.read(supabaseClientProvider)
    .from('messages')
    .stream(primaryKey: ['id'])
    .eq('conversation_id', conversationId)
    .order('created_at');
});

final canSendMessageProvider = Provider.family<bool, String>((ref, conversationId) {
  final tier = ref.watch(subscriptionTierProvider);
  final blocked = ref.watch(isBlockedProvider(conversationId)); // derived from the counterpart's id
  return tier != SubscriptionTier.free && !blocked;
});
```
- `conversationMessagesProvider` is a `StreamProvider`, not `StreamProvider.autoDispose` — losing message history when briefly navigating away (e.g. to view the counterpart's profile and back) would be a jarring UX regression for a chat screen specifically, unlike most other detail screens where a brief refetch is fine.
- `canSendMessageProvider` re-derives on every relevant state change (tier, block status) rather than being checked once when the screen loads — this mirrors the backend's own "checked per-message, not just at signup" RLS behavior (API_DATA_MODEL.md § 2, backend doc set) so the input bar's enabled/disabled state can never drift out of sync with what the server will actually accept.
- The Direct Messages List screen's conversation rows (last message preview, unread state) are a separate `AsyncNotifier` with `loadMore()` per § 2's pagination row — not itself a `StreamProvider`, since a full live-updating list of *all* conversations is more than that screen needs; only the currently-open conversation needs to be truly live.

### 4. Cross-module dependencies
Some screens genuinely need data from multiple modules at once (SCREENS_MOBILE.md § 3 Journal Entry Detail showing a linked strategy chip, § 5 Portfolio Dashboard reading `journal_entries` via the `portfolio_stats` view). Pattern: the *consuming* screen's provider reads the *other* module's provider via `ref.watch`, rather than duplicating a fetch:

```dart
final journalEntryDetailProvider = FutureProvider.family<JournalEntry, String>((ref, id) async {
  final entry = await ref.read(journalRepositoryProvider).getById(id);
  if (entry.strategyId != null) {
    // triggers/reuses the strategies module's own provider, doesn't re-implement the fetch
    ref.watch(strategyDetailProvider(entry.strategyId!));
  }
  return entry;
});
```
This keeps the Graph View (SCREENS_MOBILE.md § 3), which touches journal, strategy, and ticker data simultaneously, from becoming a special case — it's the same pattern at a larger scale (three `ref.watch` calls instead of one).

### 5. Caching & disposal
- Detail providers (`.family`) use `autoDispose` by default — when a user navigates away from Journal Entry Detail, that provider's cache clears after a short keep-alive window (`ref.keepAlive()` for 30s–1min is reasonable, avoids a full refetch on quick back-and-forth navigation, e.g. Graph View → entry → back to Graph View).
- List providers (Journal List, Strategy List, Community Feed, Watchlist List) do **not** autoDispose by default — keep them warm across tab switches so returning to a tab doesn't always show a loading skeleton. Manually invalidate (`ref.invalidate(...)`) after any mutation that affects that list (create/edit/delete entry, follow/unfollow, etc.).
- Global/app-wide providers (auth session, subscription tier, current profile) live outside any feature folder, in `core/`, and are never disposed for the life of the app session.

### 6. Optimistic updates
Used for low-risk, instantly-reversible actions where waiting for a round-trip feels laggy:
- Like/unlike a post, save/unsave a post, favorite/unfavorite a strategy or watchlist item — flip local state immediately, fire the mutation, roll back on failure with a toast ("Couldn't save — try again," CONTENT_STYLE.md error tone).
- **Not** used for anything that affects derived data elsewhere (journal entry outcome override, strategy visibility toggle) — these wait for the server round-trip because Portfolio Dashboard/Strategy Analyzer stats depend on outcome being correct, and a rolled-back optimistic update there would show briefly-wrong aggregate numbers, which is worse than a half-second delay.

### 7. Error state mapping
Every `AsyncNotifier`/`FutureProvider` surfaces three states Riverpod already models (`AsyncLoading`/`AsyncData`/`AsyncError`) — widgets map these directly to SCREENS_MOBILE.md's cross-cutting Loading/Loaded/Error states via `.when(...)`. The `AsyncError`'s error object should be the typed exception from the repository layer (mapped from the backend's ERROR_HANDLING.md status codes), not a raw `Exception` — so the UI can distinguish "show upsell interstitial" (403/429) from "show generic error + retry" (500/502) at the widget level without string-matching error messages.

### 8. Tier-gating checks (client-side)
Client-side tier checks are a **UX convenience only** — the backend's RLS/Edge Function checks (SECURITY_COMPLIANCE.md backend doc) are the actual enforcement. Pattern: a single `subscriptionTierProvider` (reads `profiles.subscription_tier`, real-time via StreamProvider so an upgrade takes effect without an app restart) that gated widgets check before attempting an action, to show the upsell interstitial (DYNAMIC_LINKING.md § 5.3 flow) *before* making a network call that would just come back `403`/`429` anyway.
