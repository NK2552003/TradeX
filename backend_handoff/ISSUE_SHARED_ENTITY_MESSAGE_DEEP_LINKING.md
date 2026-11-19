# [Bug / Feature]: Universal Deep-Linking & Exact Entity Navigation for Shared Direct Messages

**Issue Type:** `Bug / UX Architecture / Universal Link Graph`  
**Components:** `lib/core/widgets/app_scaffold.dart`, `lib/features/messages`, `lib/features/community`, `lib/features/journal`, `lib/features/strategies`, `lib/features/notes`  
**Reference Handoffs:**
- [09-Messages](../backend_handoff/09-Messages/HOW_IT_WORKS.md)
- [10-Community](../backend_handoff/10-Community/HOW_IT_WORKS.md)
- [11-Universal_Link_Graph](../backend_handoff/11-Universal_Link_Graph/HOW_IT_WORKS.md)
- [01-Trade_Journal](../backend_handoff/01-Trade_Journal/HOW_IT_WORKS.md)
- [02-Trader_Notes](../backend_handoff/02-Trader_Notes/HOW_IT_WORKS.md)
- [03-Strategy_Notes](../backend_handoff/03-Strategy_Notes/HOW_IT_WORKS.md)

---

## 1. Summary & Objective

When any record (a Community Post, Trade Journal Entry, Strategy Playbook, Trader Note, or Ticker) was shared in a conversation thread or direct message, clicking the shared reference card erroneously navigated to the **Notes landing page** (or remained stuck on an empty notes screen) instead of navigating directly to the specific destination surface and opening the exact record detail view.

This issue tracks:
1. **Root Cause Analysis:** Diagnosing the multi-layer breakdown across reference serialization, DM sharing dialogs, shell destination resolution, and surface request listeners.
2. **Universal Link Resolution Contract:** Unifying `AppLinkRef` and `AppLinkOpenRequest` so that entity kinds (`communityPost`, `journal`, `strategy`, `note`, `ticker`, `aiCopilot`, `messageThread`) and ID prefix patterns (`post_`, `pst_`, `trade_`, `entry_`, `strat_`, etc.) unambiguously map to their respective active workspace destinations.
3. **Exact Entity Detail Pushing:** Ensuring each receiving surface (`CommunityRootScreen`, `JournalScreen`, `StrategiesScreen`, `NotesScreen`, `MarketRootScreen`) consumes `openRequest` and immediately pushes the exact record detail view without user friction.
4. **Resilient Supabase Deserialization & Sync:** Ensuring Supabase chat shared references parse `communityPost` and related aliases (`post`, `community_post`) properly with ID-prefix fallback instead of defaulting to generic notes.

---

## 2. Root Cause Analysis

The bug stemmed from four interconnected breaks in the navigation pipeline:

### 2.1 Missing `sharedRef` in Direct Message Sharing (`CommunitySendDmDialog`)
When a user shared a community post to another trader via `CommunitySendDmDialog.show(context, post: post)`:
- `MessagesRepositoryScope.repository.sendMessage` was called with only a stringified `body: shareText`.
- `sharedRef` was never attached to the `ChatMessage`. Consequently, no interactive `AppLinkRefTile` was rendered, or if the conversation relied on manual reference tiles, the metadata lacked typed deep-link payloads.

### 2.2 Brittle Deserialization Fallback in `MessagesRepository`
In `MessagesRepository._loadMessagesFromSupabase`:
- The kind was parsed using `firstWhere((k) => k.name == kindStr, orElse: () => AppLinkKind.note)`.
- If a post was saved with any variation like `'post'`, `'community'`, or `'community_post'`, `firstWhere` failed and forced the reference to `AppLinkKind.note`.

### 2.3 Hardcoded and Ambiguous Destination Routing in `AppScaffold._openLinkRef`
In `AppScaffold._openLinkRef`:
```dart
void _openLinkRef(AppLinkRef ref, {bool writing = false}) {
  final String destination = writing
      ? 'notes'
      : (ref.id == 'ai_copilot' || ref.kind == AppLinkKind.aiCopilot
            ? 'ai_copilot'
            : (ref.id == 'messages' || ref.kind == AppLinkKind.messageThread
                  ? 'messages'
                  : switch (ref.kind) {
                      AppLinkKind.journal => 'journal',
                      AppLinkKind.strategy => 'strategies',
                      AppLinkKind.aiCopilot => 'ai_copilot',
                      AppLinkKind.communityPost => 'community_feed',
                      AppLinkKind.messageThread => 'messages',
                      AppLinkKind.ticker => 'market',
                      AppLinkKind.note =>
                        ref.id.startsWith('community')
                            ? 'community_feed'
                            : 'notes',
                    }));
```
- If `ref.kind` fell back to `note` (or was passed as note) for a post with ID `post_123`, `ref.id.startsWith('community')` was false, routing destination to `'notes'`.
- The shell mounted `NotesScreen(openRequest: AppLinkOpenRequest(kind: AppLinkKind.note, id: 'post_123'))`.
- `NotesScreen._apply` searched `[..._notes, ..._publicNotes]` for `note.id == 'post_123'`. Finding nothing, it returned silently, stranding the user on the root notes landing page.

### 2.4 Flawed ID Prefix Check in `CommunityRootScreen._applyRequest`
In `CommunityRootScreen._applyRequest`:
```dart
void _applyRequest(AppLinkOpenRequest request) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (request.id.startsWith('community_')) {
      final post = _repo.loadPostById(request.id);
      if (post != null) {
        _openPostDetail(post);
      }
    }
  });
}
```
- Real post IDs throughout AlphaJournal start with `post_` (e.g. `post_poll_1`, `post_nitish_1`, `post_a1`), `pst_`, or UUIDs from Supabase.
- The check `if (request.id.startsWith('community_'))` failed on 100% of real community posts, preventing `_openPostDetail` from ever firing even if `AppScaffold` correctly selected `community_feed`.

---

## 3. Architecture & Universal Deep-Linking Contract

### 3.1 Entity Kind Resolution Matrix

| Record Kind | Typical ID Prefixes | Destination Surface | Open Handler |
| :--- | :--- | :--- | :--- |
| `AppLinkKind.communityPost` | `post_`, `pst_`, `community_` | `'community_feed'` | `CommunityRootScreen._openPostDetail(post)` |
| `AppLinkKind.journal` | `trade_`, `entry_`, `trn_`, `journal_` | `'journal'` | `JournalScreen._open(id)` |
| `AppLinkKind.strategy` | `strat_`, `strategy_` | `'strategies'` | `StrategiesScreen._open(id)` |
| `AppLinkKind.note` | `note_`, `doc_` | `'notes'` | `NotesScreen._open(note)` / `_edit(note)` |
| `AppLinkKind.ticker` | `$AAPL`, `RELIANCE` | `'market'` | `MarketRootScreen.openTicker(symbol)` |
| `AppLinkKind.aiCopilot` | `ai_copilot`, `copilot` | `'ai_copilot'` | `AiAssistantRootScreen` |
| `AppLinkKind.messageThread` | `thread_`, `conv_`, `messages` | `'messages'` | `MessagesRootScreen.openThreadById(id)` |

---

## 4. Implementation Details

1. **`community_send_dm_dialog.dart`**:
   - Create typed `AppLinkRef` with `kind: AppLinkKind.communityPost` when `widget.post != null`.
   - Pass `sharedRef: postRef` to `MessagesRepositoryScope.repository.sendMessage`.
2. **`messages_repository.dart`**:
   - Parse `chat_shared_refs` kind via `AppLinkKind.fromHost` and normalized alias matching.
   - Apply prefix-based heuristic fallback if kind defaults to `note`.
3. **`app_scaffold.dart`**:
   - Introduce `_resolveRefKind` helper to normalize kind from both enum and ID prefixes.
   - Route `communityPost` to `'community_feed'`, `journal` to `'journal'`, `strategy` to `'strategies'`, etc.
   - Dispatch `AppLinkOpenRequest` with the resolved kind and ID.
4. **`community_root_screen.dart`**:
   - Update `_applyRequest` to accept `request.kind == AppLinkKind.communityPost` or any post ID pattern.
   - Load post via `_repo.loadPostById` (with fallback to `fetchPostById` for Supabase records).
   - Trigger `_openPostDetail(post)` to immediately display `CommunityPostDetailView`.
5. **`community_repository.dart`**:
   - Include `_bookmarkedPosts` in `loadPostById`.
   - Implement `fetchPostById(String postId)` to fetch and cache remote Supabase posts.
6. **`notes_screen.dart`, `journal_screen.dart`, `strategies_screen.dart`**:
   - Add graceful forwarders in `_apply` so mismatched requests immediately redirect through `widget.onOpenRef` instead of dropping silently.

---

## 5. Verification Checklist

- [x] Sharing a post from the Community feed to DM attaches an interactive `AppLinkRefTile`.
- [x] Tapping the shared post in a message thread navigates to Community Feed and opens `CommunityPostDetailView` with comments, metrics, and author details.
- [x] Sharing a Trade Journal entry into a message thread opens the specific trade document in the Journal view.
- [x] Sharing a Strategy playbook into a message thread opens the specific strategy playbook.
- [x] Static analysis passes with zero errors via `analyze_files`.
- [x] Live hot reload verified via DTD.
