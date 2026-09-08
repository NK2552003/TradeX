# Offline support and caching strategy: TradeX

This document outlines offline capabilities, caching lifecycles, and write behavior when network connectivity is absent or intermittent. For implementation details on state caching with Riverpod, see [STATE_MANAGEMENT.md](./STATE_MANAGEMENT.md).

## 1. Scope decision for MVP
TradeX operates with an online-first architecture for the MVP release. Full offline write queuing and reconciliation require dedicated synchronization engines and local databases that exceed the initial timeline. The platform implements cached read-through storage so temporary connection drops do not disrupt navigation, while write actions require an active network connection. This decision can be revisited after launch if user demand highlights a need for offline trade logging.

## 2. Cached read data and retention
| Data | Cache duration | Offline behavior |
|---|---|---|
| Journal list, Strategy list, Watchlist list, Community feed | Active session plus 5 minutes after backgrounding, or until pull-to-refresh | Displays cached data with an informational banner: "Showing cached data" |
| Journal entry, Strategy, and Post detail pages | Session keep-alive via Riverpod `autoDispose` | Displays cached view with offline indicator |
| Portfolio dashboard statistics | 5 minutes | Displays cached performance view |
| Ticker quotes and technical charts | Current session memory only; never cached across launches | Displays connection error; stale financial prices are withheld to prevent misleading data |
| AI analysis and summaries | Server-side cache (15 minutes) | Displays connection error if server cannot be reached |

## 3. Operations requiring active connectivity
- Write actions: Creating, editing, or deleting journal entries, strategies, posts, watchlist items, comments, and social interactions require a live network connection. When offline, forms display an alert: "You are offline. Connect to save your changes." Input content remains preserved in the active view to avoid accidental data loss.
- AI assistant and edge function requests: Interactive AI chat, trade evaluations, and strategy reviews require live server communication.
- Authentication: Sign up, sign in, and password recovery require verified connection to identity services.

## 4. Image caching strategy
- Trade screenshots, user avatars, and attached media use standard disk caching via `cached_network_image`. Because uploaded media assets use immutable storage paths, they are safely cached until evicted by platform memory constraints.
- Media caching functions independently from API response caching, which uses short, minute-level expiration windows.

## 5. Connectivity detection and user feedback
- An application-level `connectivityProvider` tracks network reachability and renders a subtle top banner during connection interruptions.
- Action buttons for write operations inspect connectivity state immediately, providing prompt feedback rather than waiting for server request timeouts.

## 6. Concurrent write handling
Concurrent edits across multiple devices resolve using a last-write-wins strategy aligned with the backend versioning model. Because saving a strategy creates a new record in `strategy_versions`, superseded edits remain accessible through version history rather than being permanently overwritten.

## 7. Open considerations
Implementing local draft persistence for trade creation (using storage mechanisms such as `shared_preferences` or local storage) would protect in-progress entries against accidental app closures. This targeted safeguard provides clear value while remaining within the online-first design.
