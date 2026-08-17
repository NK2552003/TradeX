# Navigation & Routing Implementation — TraderHub (go_router)

Implements the route table from [DYNAMIC_LINKING.md](./DYNAMIC_LINKING.md) § 2 as actual `go_router` configuration. That doc is the source of truth for *what* each path does; this doc is *how* it's wired in Flutter.

### 1. Router setup
Single `GoRouter` instance in `core/router/` (ARCHITECTURE.md § 3), using `ShellRoute` for the persistent nav chrome (`THAppShell`, COMPONENT_LIBRARY.md § 7) so switching tabs doesn't rebuild the whole app, only the active tab's navigation stack.

```dart
final router = GoRouter(
  initialLocation: '/',
  redirect: _authRedirect, // § 2 below
  routes: [
    ShellRoute(
      builder: (context, state, child) => THAppShell(child: child),
      routes: [
        GoRoute(path: '/journal', routes: [
          GoRoute(path: ':entryId', builder: (ctx, state) =>
            JournalEntryDetailScreen(entryId: state.pathParameters['entryId']!)),
          GoRoute(path: 'new', builder: (ctx, state) => JournalEntryCreateScreen(
            ticker: state.uri.queryParameters['ticker'],
            strategyId: state.uri.queryParameters['strategyId'],
          )),
        ], builder: (ctx, state) => const JournalListScreen()),
        GoRoute(path: '/messages', routes: [
          GoRoute(path: 'new', builder: (ctx, state) => const NewMessageScreen()),
          GoRoute(path: ':conversationId', builder: (ctx, state) =>
            ConversationDetailScreen(conversationId: state.pathParameters['conversationId']!)),
          // Note: unlike most detail routes, ':conversationId' has NO tier check in its
          // builder — a downgraded participant can still navigate here and read history
          // (DYNAMIC_LINKING.md § 2). The gate lives in canSendMessageProvider
          // (STATE_MANAGEMENT.md § 3.1), evaluated inside the screen, not at the route.
        ], builder: (ctx, state) => const DirectMessagesListScreen()),
        // ...remaining routes follow the same nesting, one GoRoute tree
        // per module matching DYNAMIC_LINKING.md § 2's path table exactly
      ],
    ),
    GoRoute(path: '/signup', builder: (ctx, state) => const SignUpScreen()),
    GoRoute(path: '/login', builder: (ctx, state) => const LogInScreen()),
    // public routes (no ShellRoute wrapper — no nav chrome for logged-out views)
    GoRoute(path: '/u/:handle', builder: (ctx, state) =>
      PublicProfileScreen(handle: state.pathParameters['handle']!)),
  ],
);
```

### 2. Auth guard (`redirect`)
Single `redirect` callback implements the "store intended destination, redirect through auth, replay" pattern from DYNAMIC_LINKING.md § 5.1/5.5:

```dart
String? _authRedirect(BuildContext context, GoRouterState state) {
  final isLoggedIn = ref.read(authSessionProvider) != null;
  final isPublicRoute = _publicRoutes.any((p) => state.matchedLocation.startsWith(p));
  if (!isLoggedIn && !isPublicRoute) {
    return '/login?redirect=${Uri.encodeComponent(state.uri.toString())}';
  }
  if (isLoggedIn && (state.matchedLocation == '/login' || state.matchedLocation == '/signup')) {
    final redirectTo = state.uri.queryParameters['redirect'];
    return redirectTo ?? '/';
  }
  return null;
}
```
`_publicRoutes` is exactly the list from DYNAMIC_LINKING.md § 2's "No" auth-required rows: `/u/`, `/strategies/{id}` (conditionally — see § 3 below), `/community/{postId}`, plus the auth screens themselves.

### 3. Conditional public routes (public Strategy Notes)
Strategy Detail is public **only when** `strategies.visibility = 'public'` (DYNAMIC_LINKING.md § 2) — this can't be decided purely from the path, so the guard for this one route is different: allow the navigation through unauthenticated, and let the screen itself fetch and show either the public read-only view or a 404-equivalent "This strategy isn't available" state (ERROR_HANDLING.md backend doc § 2's deliberate 404-for-both-not-found-and-private convention) rather than gating at the router level.

### 4. Deep link handling (external entry)
- **Cold start:** `go_router`'s built-in platform deep-link support (via `GoRouter.routeInformationParser`) handles both `traderhub://` and `https://traderhub.app/` the same way, per DYNAMIC_LINKING.md § 1 — both are registered as associated domains/intent filters at the native project level (iOS `apple-app-site-association`, Android `assetlinks.json`), not something the Dart routing code needs to distinguish between.
- **Notification tap (warm/background):** `notifications.deep_link` (a path string, per DYNAMIC_LINKING.md § 3) is passed directly to `router.go(deepLink)` — no separate mapping table needed in the client, the backend already stores a ready-to-use path.

### 5. Tier-gated route interception
The upsell interstitial flow (DYNAMIC_LINKING.md § 5.3) is implemented as a check **before** calling `context.go()`, not as a route guard — because the "originally tapped screen" needs to be remembered for the post-upgrade redirect, which is cleaner as a widget-level intercept than a router-level one:

```dart
void navigateToGated(BuildContext context, WidgetRef ref, String targetPath, String featureId) {
  final tier = ref.read(subscriptionTierProvider);
  if (tier == SubscriptionTier.free && _gatedFeatures.contains(featureId)) {
    context.go('/paywall?feature=$featureId&redirect=${Uri.encodeComponent(targetPath)}');
  } else {
    context.go(targetPath);
  }
}
```

Every Direct Messages entry point (the Messages icon on Community Feed, a "Message" button on a Public Profile, the new-message FAB) routes through this same `navigateToGated('/messages', ref, ..., featureId: 'direct_messages')` call rather than a bespoke check — it's the same pattern already used for Strategy Notes and Watchlists gating, not a special case. The one place Direct Messages diverges from this pattern is *inside* an already-open `Conversation Detail` (§ 1's note above) — that screen is reachable regardless of tier, and gates sending rather than navigation.

### 6. Master-detail routing (tablet/desktop)
SCREENS_TABLET.md § 2's split-pane pattern doesn't change the route table — `/journal/:entryId` is still the canonical path for a detail view — but `THMasterDetailScaffold` (COMPONENT_LIBRARY.md § 7) reads the current route to decide whether to render the detail pane inline (tablet/desktop, wide enough) or push a new full screen (mobile). This means the same route config serves all three device classes; only the shell widget's rendering decision changes based on `MediaQuery` width.

### 7. Not yet decided
- Global desktop search (SCREENS_DESKTOP.md § 6) — flagged in DYNAMIC_LINKING.md § 6 as having no route entry. Recommend implementing as a modal overlay state (a `showTHCommandPalette()` call) rather than a real route, so it doesn't pollute browser history with search-in-progress states — but this needs a decision before implementation, not an assumption baked in here.
- Enterprise routes (`/org/...`) are entirely absent from the router until the `organizations` data model exists (ROADMAP.md, backend doc set) — don't scaffold empty route stubs for these ahead of time, add them when the feature is actually built.
