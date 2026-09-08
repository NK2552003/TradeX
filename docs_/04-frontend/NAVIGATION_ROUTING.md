# Navigation and routing: TradeX

TradeX ships **without a router**. Sections 1–4 describe the navigation model that is in the code today and that every feature must implement against. Sections 5–11 specify the `go_router` configuration to adopt when the app gains web and Universal Link entry points, and are a migration target, not a description of the current tree.

The URL space and cross-destination link contract are in [DYNAMIC_LINKING.md](../03-design/DYNAMIC_LINKING.md).

## 1. What ships today: one shell, one selected id

[lib/core/widgets/app_scaffold.dart](../../lib/core/widgets/app_scaffold.dart) holds a `String _selectedId` and swaps a single widget per sidebar destination:

```dart
Widget _traderPage() => switch (_selectedId) {
  'overview' => UiSkeleton.dashboard(),
  'journal' => JournalScreen(
    onSubpageChanged: _onSubpageChanged,
    onOpenRef: _openLinkRef,
    openRequest: _linkRequest,
  ),
  'notes' => NotesScreen(onOpenRef: _openLinkRef, openRequest: _linkRequest),
  'strategies' => StrategiesScreen(
    onSubpageChanged: _onSubpageChanged,
    onOpenRef: _openLinkRef,
    openRequest: _linkRequest,
  ),
  'calculators' => CalculatorsScreen(onSubpageChanged: _onSubpageChanged),
  _ => _destinationSkeleton(_selectedId),
};
```

Three consequences follow, and they are the reason the writing surfaces are built the way they are:

- **There is no `Navigator.push` for a destination.** `_go(id)` is a `setState`. Nothing is on a stack, so nothing can be popped back to.
- **Screens own their own inner navigation.** Index → document → editor is a state machine inside the screen, not a route stack. A phone's back gesture is mediated by the shell, not by `Navigator`.
- **Role changes the reachable set.** `_canReach(id)` gates which destinations exist for a trader, affiliate or admin shell; `_traderPage`, `_affiliatePage` and `_adminPage` are separate switches, and the affiliate/admin shells intentionally mount `const NotesScreen()` with no linking affordances.

## 2. The subpage protocol (a phone's back step without a Navigator)

A screen that opens a document on a phone has taken a step the user must be able to reverse. It reports that step upward:

```dart
typedef AppSubpageChanged =
    void Function(String? title, IconData? icon, VoidCallback? onBack);
```

The shell stores the three values, renders `title`/`icon` in the app bar and wires `onBack` to the leading button and the system back gesture. Passing `(null, null, null)` means "I am back at my index, the destination name is yours again".

Rules a screen must follow:

| Rule | Why |
|---|---|
| Report only for steps the user can reverse | An inline editor sheet that closes itself must not claim the app bar |
| Report on the phone layout only | On desktop the document is beside the index, so no step was taken |
| Report `null` on the way back, not just on the way in | Otherwise the app bar keeps naming a document the user has left |
| Never report during `build` | The shell calls `setState`; schedule from a callback or a post-frame callback |

`JournalScreen` and `StrategiesScreen` both implement this, and their widget tests assert both directions — an announced title after tapping a card, and a null title after invoking the reported `onBack`. `NotesScreen` does not take part: its reader and editor are full-screen surfaces that carry their own chrome.

## 3. Cross-destination links

The shell owns `AppLinkOpenRequest? _linkRequest` and `int _linkSeq`, and hands the request to whichever screen mounts next. The protocol, the four decline cases and the reason the request is cleared on manual navigation are specified in [DYNAMIC_LINKING.md](../03-design/DYNAMIC_LINKING.md#3-cross-destination-navigation-no-router). The frontend obligation is narrow:

- A screen applies `openRequest` in `initState` **and** in `didUpdateWidget` when `widget.openRequest != oldWidget.openRequest`. `AppLinkOpenRequest` is value-equal including `seq`, so this comparison is the whole trigger.
- A screen **ignores a request whose `kind` is not its own**. This is asserted by a test in both `journal_screen_test.dart` and `strategies_screen_test.dart`; a misrouted request must leave the rail's own selection alone rather than open a wrong-typed id.
- A screen raises `onOpenRef` for every link it renders, including ones pointing into itself. The shell declines the same-destination case, and the screen handles it as a local selection change.

## 4. Responsive layout is not responsive routing

Phone and desktop are **different surfaces**, not one layout reflowing:

| Destination | Phone | Desktop |
|---|---|---|
| Journal notes | Card grid, one column; tapping opens a document that replaces it and takes a back step | `AppWorkbenchLayout`: index rail + open document + linked-records column, all mounted at once |
| Strategy notes | Playbook library grid; same replace-and-back step | Same workbench shape as the journal, on purpose |
| Trader notes | Grid → full-screen reader → full-screen editor | Grid → reader with a details rail → editor with a details rail |

The two branches build genuinely different widget trees, and the tests assert the *absence* of the other branch's widgets (`AppJournalNoteGrid` findsNothing on desktop, `AppWorkbenchLayout` findsNothing on a phone). When the router lands, both branches keep the same canonical path — see section 10.

---

## 5. Router setup (migration target)
A centralized `GoRouter` instance in `core/router/` uses `ShellRoute` to house persistent navigation chrome (`AppScaffold`). Switching tabs rebuilds only the active tab stack rather than the entire widget tree.

```dart
final router = GoRouter(
  initialLocation: '/',
  redirect: _authRedirect,
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppScaffold(child: child),
      routes: [
        GoRoute(
          path: '/journal',
          builder: (ctx, state) => const JournalScreen(),
          routes: [
            GoRoute(
              path: ':entryId',
              builder: (ctx, state) => JournalScreen(
                openId: state.pathParameters['entryId']!,
              ),
            ),
            GoRoute(
              path: 'new',
              builder: (ctx, state) => JournalEntryCreateScreen(
                ticker: state.uri.queryParameters['ticker'],
                strategyId: state.uri.queryParameters['strategyId'],
              ),
            ),
          ],
        ),
        // Trader notes and strategy notes take the same shape. The screens
        // already accept "open this record" as data (`openRequest`), so the
        // router supplies an id rather than mounting a different widget — the
        // desktop workbench and the phone's document must stay one route.
        GoRoute(
          path: '/notes',
          builder: (ctx, state) => const NotesScreen(),
          routes: [
            GoRoute(
              path: ':noteId',
              builder: (ctx, state) =>
                  NotesScreen(openId: state.pathParameters['noteId']!),
            ),
          ],
        ),
        GoRoute(
          path: '/strategies',
          builder: (ctx, state) => const StrategiesScreen(),
          routes: [
            GoRoute(
              path: ':strategyId',
              builder: (ctx, state) => StrategiesScreen(
                openId: state.pathParameters['strategyId']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/messages',
          builder: (ctx, state) => const DirectMessagesListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (ctx, state) => const NewMessageScreen(),
            ),
            GoRoute(
              path: ':conversationId',
              builder: (ctx, state) => ConversationDetailScreen(
                conversationId: state.pathParameters['conversationId']!,
              ),
              // Downgraded users can still open existing conversation threads
              // to read history. Restrictions are enforced on sending via
              // canSendMessageProvider, not at the route level.
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/signup', builder: (ctx, state) => const SignUpScreen()),
    GoRoute(path: '/login', builder: (ctx, state) => const LogInScreen()),
    // Public routes without persistent navigation chrome
    GoRoute(
      path: '/u/:handle',
      builder: (ctx, state) => PublicProfileScreen(
        handle: state.pathParameters['handle']!,
      ),
    ),
  ],
);
```

## 6. Authentication guard and redirects
A single redirect callback stores the intended destination, redirects unauthenticated users through login, and restores the original path after login:

```dart
String? _authRedirect(BuildContext context, GoRouterState state) {
  final isLoggedIn = ref.read(authSessionProvider) != null;
  final isPublicRoute = _publicRoutes.any(
    (p) => state.matchedLocation.startsWith(p),
  );

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

Public routes include `/u/`, `/strategies/{id}` and `/notes/{id}` (both evaluated conditionally), `/community/{postId}`, and authentication screens. `/journal` is never public at any depth.

## 7. Conditional public routes
Strategy documents are public only when `strategies.visibility = 'public'`; trader notes only when `trader_notes.is_public`. Because visibility cannot be determined from URL paths alone, the router permits unauthenticated navigation to the screen. The presentation layer then verifies permissions, displaying public content or rendering an unavailable notice if the record is private or missing.

A public document must not leak its edges. The linked-records panel is populated from the link graph, which on an authenticated client holds the whole workspace — so a public read path has to strip refs the visitor cannot see **server-side**, before they reach the client. Hiding them in the widget is not sufficient and must not be relied on.

## 8. Deep link handling
- Cold launches: Platform deep linking via `GoRouter.routeInformationParser` resolves both the custom URI scheme (`tradex://`) and universal web links (`https://tradex.app/`). Native configurations (`apple-app-site-association` on iOS and `assetlinks.json` on Android) manage domain verification.
- Internal content links: markdown bodies already store `tradex://` URLs (see [DYNAMIC_LINKING.md](../03-design/DYNAMIC_LINKING.md#1-the-internal-tradex-url-space)). These resolve through `AppDeepLink.target` today and must keep doing so after the router lands — the router handles *arriving from outside*, not links inside a document.
- Notification triggers: The `notifications.deep_link` path string routes directly to `router.go(deepLink)` without additional client translation tables.

## 9. Tier-gated route interception
Upsell interstitials are evaluated before initiating navigation rather than through router guards. This approach preserves the target destination for post-checkout redirection:

```dart
void navigateToGated(
  BuildContext context,
  WidgetRef ref,
  String targetPath,
  String featureId,
) {
  final tier = ref.read(subscriptionTierProvider);
  if (tier == SubscriptionTier.free && _gatedFeatures.contains(featureId)) {
    context.go(
      '/paywall?feature=$featureId&redirect=${Uri.encodeComponent(targetPath)}',
    );
  } else {
    context.go(targetPath);
  }
}
```

Direct messaging entry points use `navigateToGated('/messages', ref, ..., featureId: 'direct_messages')`. Active conversation threads permit navigation across all tiers and enforce restrictions at the composer level.

## 10. Master-detail responsive routing
The workbench layout on tablet and desktop uses the same canonical path as the phone (`/journal/:entryId`, `/strategies/:strategyId`, `/notes/:noteId`). One path, two surfaces: the screen inspects `context.uiRes` and either mounts its index rail beside the document or replaces the index with it. This is why section 5 passes an id into the *same* screen widget on both the list and detail routes rather than routing to a separate detail screen — a detail-only route would have no index to sit beside on a desktop.

A phone's detail route must still report its back step through the subpage protocol of section 2 while the shell chrome remains the shell's; `context.pop()` and the reported `onBack` have to end up doing the same thing.

## 11. Open considerations
- Global search on desktop: Recommended as a modal overlay (via a command palette) rather than a dedicated route to avoid cluttering browser navigation history with partial search queries.
- Enterprise routes (`/org/...`): Excluded from initial router definitions until organization data models are implemented.
- Editor routes: `/notes/{id}/edit` is deliberately absent. The editor holds unsaved text; a URL that can be shared, bookmarked or hit with a browser back button while a draft is dirty needs a discard contract that the shipped inline editor does not need.
