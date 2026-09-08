# State management: TradeX (Riverpod)

This document describes how data flows from Supabase into Flutter widgets and defines Riverpod provider conventions across all feature modules. For folder architecture, see [ARCHITECTURE.md](../02-architecture/ARCHITECTURE.md). Backend API contracts are detailed in [API_REFERENCE.md](../02-architecture/API_REFERENCE.md) and [API_DATA_MODEL.md](../02-architecture/API_DATA_MODEL.md).

## 1. Provider layering
Each feature directory under `features/<module>/` follows a three-layer architecture:

```text
data/         Repositories executing Supabase SDK queries (one method per operation)
domain/       Providers wrapping repositories and exposing typed state to the UI
presentation/ Widgets consuming providers via ref.watch and ref.read
```

Widgets must never import `supabase_flutter` directly. Consuming data through domain providers keeps authorization and network errors consistently mapped to UI states in a single location per module.

## 2. Provider types by data shape

| Data shape | Provider type | Examples |
|---|---|---|
| Single fetch operations (list or detail) | `AsyncNotifierProvider`, `FutureProvider.family` | Journal list, Strategy detail |
| Live updates (Supabase realtime subscriptions) | `StreamProvider` | Notification center badge, post reactions, conversation messages |
| Local UI state (transient) | `StateProvider`, `NotifierProvider` | Filter sheet parameters before submission, form drafts, active chart timeframe |
| Paginated collections | `AsyncNotifier` with explicit `loadMore()` implementation | Journal entries, Community feed, Direct messages directory |

## 3. Family providers for parameterized queries
Providers requiring parameters use the `.family` modifier: `journalEntryDetailProvider(entryId)`, `strategyDetailProvider(strategyId)`, `watchlistDetailProvider(watchlistId)`, and `conversationMessagesProvider(conversationId)`. This allows Riverpod to cache items per identifier and release unused resources via `autoDispose`.

### 3.1 Direct messages as a realtime family provider
Direct messaging provides live bidirectional updates:

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
  final blocked = ref.watch(isBlockedProvider(conversationId));
  return tier != SubscriptionTier.free && !blocked;
});
```

Key considerations for messaging state:
- The `conversationMessagesProvider` avoids automatic disposal so message history remains cached when briefly navigating to profile previews.
- The `canSendMessageProvider` recalculates dynamically whenever subscription tier or user block status changes, ensuring the composer state remains synchronized with server rules.
- The conversation directory uses an `AsyncNotifier` with pagination rather than an active stream across all threads, limiting real-time socket connections to the active conversation.

## 4. Cross-module data dependencies
When screens require data spanning multiple features, consuming providers inspect related feature providers using `ref.watch`:

```dart
final journalEntryDetailProvider = FutureProvider.family<JournalEntry, String>((ref, id) async {
  final entry = await ref.read(journalRepositoryProvider).getById(id);
  if (entry.strategyId != null) {
    ref.watch(strategyDetailProvider(entry.strategyId!));
  }
  return entry;
});
```

This pattern scales cleanly to composite views, including the interactive graph canvas, which combines trade, strategy, and market data sources through standard provider composition.

## 5. Caching and resource disposal
- Detail providers (`.family`) use `autoDispose` to release cached records when screens unmount. Retaining state for 30 to 60 seconds with `ref.keepAlive()` prevents duplicate network requests during frequent back-and-forth navigation.
- Collection providers (such as Journal List, Strategy List, and Community Feed) remain in memory across tab switches to prevent unnecessary skeleton loading states. Mutations explicitly invalidate affected providers using `ref.invalidate()`.
- Global session state (authentication tokens, active subscription tier, current user profile) resides in `core/` and persists throughout the application lifecycle.

## 6. Optimistic UI updates
Low-risk interactions update local state immediately and roll back on failure:
- Actions such as liking posts, saving bookmarks, and favoriting strategies update the UI instantly, dispatching the network request in the background and displaying an error toast on failure.
- Critical business values (trade outcomes, strategy visibility) wait for server confirmation before updating the UI, preventing derived metrics in portfolio dashboards from displaying transient, inaccurate data.

## 7. Error state mapping
Providers expose standard asynchronous states (`AsyncLoading`, `AsyncData`, `AsyncError`). Widgets map these states directly to visual presentations using `.when()`. The repository layer returns typed exceptions derived from backend error codes, allowing widgets to distinguish paywall triggers (status 403 or 429) from connection failures (status 500 or 502) without parsing string messages.

## 8. Client-side subscription tier verification
Client-side tier evaluations provide immediate feedback, while backend database policies enforce access security. A central `subscriptionTierProvider` tracks user tiers through an active stream, allowing restricted controls to display upgrade prompts before dispatching unauthorized network requests.
