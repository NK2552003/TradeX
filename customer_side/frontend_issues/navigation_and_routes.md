# Frontend Navigation, Routing & Deep Linking Architecture

**Target Audience:** Frontend Flutter Engineers  
**Scope:** Navigation Architecture, Declarative Routing Migration (`go_router`), Browser History Sync, Deep Linking & Mobile Intent Filters, and Android Back-Button Trapping.  
**Date:** 2026-10-21  

---

## 1. Executive Summary & Architectural Conflict

TradeX currently operates with **four competing, disconnected navigation mechanisms**:
1. **Auth Level:** `AuthWrapper` procedural stage switching (`AuthStage.splash` $\rightarrow$ `onboarding` $\rightarrow$ `login` $\rightarrow$ `authenticated`).
2. **Shell Level:** `AppScaffold._selectedId` string destination switching (`workspace`, `journal`, `community`, `messages`, `settings`, etc.).
3. **Feature Level:** `CommunityRootScreen._tabController` and `MarketRootScreen` internal tab controllers.
4. **Imperative Dialog Level:** `Navigator.of(context).push(...)` and `showModalBottomSheet(...)`.

Because the app is initialized with legacy procedural `MaterialApp(home: const AuthWrapper())` rather than `MaterialApp.router`, the web browser URL bar remains permanently static (`/`), deep links cannot be resolved, browser back/forward buttons break state, and Android system back gestures frequently trap users in infinite loops.

---

## 2. Core Defect Analysis

### 2.1. Complete Absence of Declarative Routing on Flutter Web
- **Location:** `lib/app.dart` (Lines 60–75).
- **Code Trace:**
  ```dart
  MaterialApp(
    title: AppConstants.appName,
    themeMode: _themeController.value,
    home: const AuthWrapper(),
  )
  ```
- **Consequence:**
  - On Flutter Web, navigating to `https://tradex.ai/community/post/abc-123` or hitting browser refresh (`Cmd+R` / `F5`) drops the sub-path and forces the user back to `AuthWrapper` (landing on default Workspace or Login).
  - External shared links sent via messaging apps (WhatsApp, Telegram) cannot route the recipient to the intended chart or discussion.

---

### 2.2. Missing Mobile OS Deep Link Intent Filters
- **Locations:** `android/app/src/main/AndroidManifest.xml` & `ios/Runner/Info.plist`.
- **Defect:**
  - `AndroidManifest.xml` only declares default launcher intent filters; it lacks `android.intent.action.VIEW` filters for custom schemes (`tradex://`) and App Links (`https://tradex.ai`).
  - `ios/Runner/Info.plist` lacks `CFBundleURLTypes` declarations and Associated Domains entitlements (`applinks:tradex.ai`).
- **Remediation:** Add intent filters in `AndroidManifest.xml`:
  ```xml
  <intent-filter android:autoVerify="true">
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="https" android:host="tradex.ai" />
      <data android:scheme="tradex" />
  </intent-filter>
  ```

---

### 2.3. Back-Stack Trapping & Android System Navigation Flaws
- **Location:** `lib/core/widgets/app_scaffold.dart` (Lines 1300–1335).
- **Code Trace:**
  ```dart
  PopScope(
    canPop: _activeSubpageOnBack == null &&
            !_showAffiliateApplication &&
            _destinationHistory.isEmpty,
    onPopInvokedWithResult: (bool didPop, Object? result) {
      if (didPop) return;
      if (_showAffiliateApplication) {
        setState(() => _showAffiliateApplication = false);
        return;
      }
      if (_activeSubpageOnBack != null) {
        _activeSubpageOnBack!();
        return;
      }
      if (_destinationHistory.isNotEmpty) {
        final String previous = _destinationHistory.removeLast();
        setState(() => _selectedId = previous);
        return;
      }
    },
  )
  ```
- **Failure Modes:**
  1. **Subpage Desynchronization:** If an inner subpage (e.g. Post Detail) is closed via an in-page close button instead of the system back button, `_activeSubpageOnBack` is not cleared. Pressing back later invokes the dead callback.
  2. **Infinite Destination Replays:** Moving between Workspace $\rightarrow$ Community $\rightarrow$ Workspace adds each step to `_destinationHistory`. Pressing back replays every single click in reverse before exiting.
  3. **Browser History Collision:** On Web, `PopScope` does not synchronize with browser history. Pressing the browser back button can exit the application entirely rather than closing an open sheet.

---

### 2.4. Sub-Tab State Desynchronization in `CommunityRootScreen`
- **Location:** `lib/core/widgets/app_scaffold.dart:790–825` vs `lib/features/community/presentation/community_root_screen.dart:140–180`.
- **Defect:**
  In `AppScaffold`, sidebar selection passes `initialTabIndex`:
  ```dart
  _communityPage(initialTabIndex: initialTabIndex)
  ```
  However, `CommunityRootScreen` is keyed strictly by:
  ```dart
  key: ValueKey<String>('community_root_${_effectiveRole.id}')
  ```
  Because the key omits `_selectedId` or `initialTabIndex`, Flutter reuses `_CommunityRootScreenState`. In `didUpdateWidget`, if `widget.initialTabIndex == oldWidget.initialTabIndex`, `_tabController` does not animate.
- **User Impact:** A user starting on Feed, swiping to Explore, and then clicking "Feed" in the sidebar remains trapped on Explore.
- **Remediation:** Include `initialTabIndex` in the widget key:
  ```dart
  key: ValueKey<String>('community_root_${_effectiveRole.id}_$initialTabIndex')
  ```

---

## 3. Migration Plan to Declarative `go_router`

To unify navigation across Web, Mobile, and Desktop, migrate `MaterialApp` to `MaterialApp.router` using `go_router` with `StatefulShellRoute.indexedStack`:

```dart
final goRouter = GoRouter(
  initialLocation: '/workspace',
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthWrapper(),
      routes: [
        GoRoute(path: 'login', builder: (context, state) => const LoginPage()),
        GoRoute(path: 'signup', builder: (context, state) => const SignUpPage()),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppScaffold(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/workspace',
              builder: (context, state) => const WorkspaceScreen(),
              routes: [
                GoRoute(path: 'journal/:id', builder: (context, state) => ...),
                GoRoute(path: 'notes/:id', builder: (context, state) => ...),
                GoRoute(path: 'strategies/:id', builder: (context, state) => ...),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/market', builder: (context, state) => const MarketRootScreen()),
            GoRoute(path: '/market/:symbol', builder: (context, state) => ...),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/community', builder: (context, state) => const CommunityRootScreen()),
            GoRoute(path: '/community/post/:id', builder: (context, state) => ...),
          ],
        ),
      ],
    ),
  ],
);
```
