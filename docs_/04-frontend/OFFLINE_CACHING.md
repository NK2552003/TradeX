# Offline Support & Caching Strategy — TraderHub

What works without a network connection, what's cached and for how long, and how conflicts are handled. Provider-level caching mechanics: [STATE_MANAGEMENT.md](./STATE_MANAGEMENT.md) § 5.

### 1. Scope decision for MVP
**TraderHub is online-first, not offline-first, for MVP.** Full offline read/write with sync-on-reconnect is a meaningfully large engineering investment (conflict resolution, a local database, a sync queue) that isn't justified by the PRD's 6-10 week MVP goal. What's specced below is a lighter middle ground: cached reads so the app doesn't feel broken on a flaky connection, but writes require connectivity. This should be treated as a deliberate scope line, not an oversight — revisit post-MVP if user feedback specifically asks for offline journaling (a plausible request, since traders may want to log a trade with spotty connectivity).

### 2. What's cached (read-through, short TTL)
| Data | Cache duration | Behavior when offline |
|---|---|---|
| Journal List, Strategy List, Watchlist List, Community Feed (last-loaded page) | Until app backgrounded + 5 min, or explicit pull-to-refresh | Shows last-known data with a subtle "offline — showing cached data" banner rather than the Error state |
| Journal Entry Detail, Strategy Detail, Post Detail (recently viewed) | Same as above, per-ID via `autoDispose` keep-alive (STATE_MANAGEMENT.md § 5) | Same cached-data banner |
| Portfolio Dashboard stats | 5 min (matches the general list cache — no special TTL, since `portfolio_stats` itself isn't real-time-critical) | Cached data banner |
| Ticker prices/charts | **Not cached beyond the current session** — price data going stale silently is actively misleading for a trading app, worse than showing an error | Error state, not stale data, if offline |
| `ai_insights`-backed content (AI summaries) | Server already caches these for 15 min (backend API_DATA_MODEL.md § 3) — client doesn't need its own separate cache layer on top, just reflects whatever the server returns | Error state if the request can't complete at all |

### 3. What's never cached / always requires connectivity
- Any **write** operation (create/edit/delete journal entry, strategy, post, watchlist item, comment, like, follow) — MVP does not queue writes for later sync. If the app is offline when a user taps Save, show a clear "You're offline — connect to save" state (not a silent failure, not a fake-success toast) and keep the form populated so nothing is lost, but don't pretend the save happened.
- AI Trading Assistant chat, all AI Edge Function calls — inherently require a live round-trip.
- Auth (sign up/log in) — obviously requires connectivity.

### 4. Image caching
- Screenshots, avatars, post images, strategy embedded images: standard Flutter image cache (`cached_network_image` or equivalent) — these are genuinely safe to cache aggressively and long-term since they're immutable once uploaded (a screenshot doesn't change after the fact). No TTL needed beyond normal cache-eviction-under-memory-pressure behavior.
- This is a different caching tier from § 2's data caching — images cache indefinitely (until evicted), data caches briefly (minutes) — don't conflate the two when implementing.

### 5. Connectivity detection & UI signaling
- A single app-wide `connectivityProvider` (wraps a connectivity-check package) drives a persistent-but-unobtrusive banner (not a blocking modal) shown across all screens when offline — appears above the top bar, dismissible individually per screen but reappears on next screen if still offline.
- Gated actions (Save buttons, Post button, etc.) check connectivity before attempting a write and show the "You're offline" message from § 3 immediately, rather than letting the request time out first — faster feedback, and avoids a confusing loading-spinner-then-error sequence.

### 6. Conflict handling (the one write-adjacent case that does need thought)
Even without offline writes, two authenticated devices/tabs editing the same entity concurrently is possible (e.g. editing a Strategy Note on phone and tablet at once). MVP approach: **last-write-wins**, consistent with the backend's `strategy_versions` model — every save creates a new version (backend API_DATA_MODEL.md), so no data is silently destroyed even if a save "loses" a race; the losing edit is still recoverable via Version History. No client-side conflict UI (e.g. a merge prompt) is planned for MVP — flagged as acceptable given `strategy_versions` already provides a recovery path, but not true conflict prevention.

### 7. Not yet decided
- Whether Journal Entry Create should locally persist an in-progress draft (e.g. via `shared_preferences` or a local Hive box) so a killed app / accidental navigation-away doesn't lose a half-written entry — this is a smaller, more justified scope than full offline sync, and worth considering even within the online-first MVP decision in § 1. Flagged as a likely quick win, not yet committed to the plan.
